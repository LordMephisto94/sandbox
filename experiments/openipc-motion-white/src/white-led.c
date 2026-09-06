/* G5C-LQ/S38 only. Bounded PWM1 test using verified open_pwm ioctl ABI.
 * GPIO4 is acquired through gpiolib; pad mux uses /dev/mem.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

struct request {
    uint8_t channel, pad0[3];
    uint32_t high, total;
    uint8_t enable, pad1[3];
};
_Static_assert(sizeof(struct request) == 16, "PWM ABI");
static volatile sig_atomic_t interrupted;
static void stop(int sig) { interrupted = sig; }

static int read_text(const char *path, char *buf, size_t size)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) { perror(path); return -1; }
    ssize_t n = read(fd, buf, size - 1);
    int saved = errno;
    close(fd);
    if (n <= 0) { errno = n < 0 ? saved : EIO; perror(path); return -1; }
    buf[n] = '\0';
    return 0;
}

static int write_text(const char *path, const char *text)
{
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) { perror(path); return -1; }
    size_t len = strlen(text);
    ssize_t n = write(fd, text, len);
    int saved = errno;
    int closed = close(fd);
    if (n != (ssize_t)len) {
        errno = n < 0 ? saved : EIO;
        perror(path);
        return -1;
    }
    if (closed < 0) { perror("close sysfs"); return -1; }
    return 0;
}

static volatile uint32_t *map_page(int fd, uint32_t address, long size)
{
    void *p = mmap(NULL, (size_t)size, PROT_READ | PROT_WRITE,
                   MAP_SHARED, fd, (off_t)address);
    if (p == MAP_FAILED) { perror("mmap"); return NULL; }
    return p;
}

static void pad_mode(volatile uint32_t *pad, int pwm)
{
    uint32_t old = *pad;
    *pad = pwm ? ((old & ~0x20fu) | 1u) : ((old & ~0xfu) | 0x200u);
    __sync_synchronize();
    (void)*pad;
}

int main(int argc, char **argv)
{
    int apply = 0, reuse = 0, arg = 1;
    unsigned high_count = 6;
    while (arg < argc) {
        if (!strcmp(argv[arg], "--apply")) apply = 1;
        else if (!strcmp(argv[arg], "--reuse-gpio4")) reuse = 1;
        else if (!strcmp(argv[arg], "--high-count")) {
            if (++arg >= argc || !*argv[arg] ||
                strspn(argv[arg], "0123456789") != strlen(argv[arg])) {
                fputs("--high-count requires an integer from 2 to 110\n", stderr); return 2;
            }
            errno = 0;
            unsigned long value = strtoul(argv[arg], NULL, 10);
            if (errno || value < 2 || value > 110) {
                fputs("--high-count must be 2..110\n", stderr); return 2;
            }
            high_count = (unsigned)value;
        }
        else break;
        arg++;
    }
    const char *action = arg == argc - 1 ? argv[arg] : "";
    int lease = !strcmp(action, "lease");
    int pulse = !strcmp(action, "test") || lease;
    if (!pulse && strcmp(action, "off")) {
        fprintf(stderr, "Usage: %s [--apply] [--reuse-gpio4] [--high-count 2..110] test|off|lease\n"
                "test: PWM1 raw total=111, default high=6, one second then GPIO4 low.\n"
                "Default is dry run. For G5C-LQ/S38 with verified open_pwm only.\n", argv[0]);
        return 2;
    }
    if (pulse)
        printf("%s: PWM1 count %u/111 %s, then GPIO4 low\n", apply ? "APPLY" : "DRY RUN",
               high_count, lease ? "while lease is renewed" : "for one second");
    else printf("%s: GPIO4 low and PWM1 disabled\n", apply ? "APPLY" : "DRY RUN");
    if (reuse) puts("Reuse existing GPIO4 export; leave it exported as output low.");
    if (lease) puts("Lease mode: requires heartbeat on stdin every second; off after four seconds without one.");
    if (!apply) return 0;

    int rc = 1, claimed = 0, touched = 0;
    int mem = -1, pwmfd = -1;
    volatile uint32_t *mux = NULL, *clock = NULL, *regs = NULL;
    long size = sysconf(_SC_PAGESIZE);
    if (size != 4096) { fputs("Expected 4096-byte pages\n", stderr); return 1; }
    struct sigaction sa = {0};
    sa.sa_handler = stop;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGINT, &sa, NULL) || sigaction(SIGTERM, &sa, NULL) ||
        sigaction(SIGHUP, &sa, NULL)) { perror("sigaction"); return 1; }
    pwmfd = open("/dev/pwm", O_RDWR | O_CLOEXEC);
    if (pwmfd < 0) { perror("/dev/pwm"); goto done; }
    struct stat st;
    if (fstat(pwmfd, &st) || !S_ISCHR(st.st_mode)) {
        fputs("/dev/pwm must be a character device\n", stderr); goto done;
    }
    mem = open("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC);
    if (mem < 0) { perror("/dev/mem"); goto done; }
    mux = map_page(mem, 0x100c0000, size);
    clock = map_page(mem, 0x12010000, size);
    regs = map_page(mem, 0x12080000, size);
    if (!mux || !clock || !regs) goto done;
    unsigned mode = mux[4] & 15;
    if (mode > 1) {
        fputs("GPIO4 pad is assigned to UART/I2C; refusing.\n", stderr); goto done;
    }
    if (pulse && (clock[0x1bc/4] != 0x282 || regs[0x2c/4] != 0)) {
        fputs("Test requires observed clock 0x282 and disabled PWM1.\n", stderr); goto done;
    }
    if (reuse) {
        char polarity[16], direction[16], value[16];
        if (read_text("/sys/class/gpio/gpio4/active_low", polarity, sizeof polarity) ||
            read_text("/sys/class/gpio/gpio4/direction", direction, sizeof direction) ||
            read_text("/sys/class/gpio/gpio4/value", value, sizeof value)) goto done;
        if (strcmp(polarity, "0\n") || strcmp(value, "0\n") ||
            (strcmp(direction, "in\n") && strcmp(direction, "out\n"))) {
            fputs("Reuse requires GPIO4 normal polarity and current value 0.\n", stderr);
            goto done;
        }
    } else {
        /* Refuse an existing export unless explicitly selected above. */
        if (write_text("/sys/class/gpio/export", "4\n")) goto done;
        claimed = 1;
    }
    if (interrupted) goto done;
    if (write_text("/sys/class/gpio/gpio4/direction", "low\n")) goto done;
    touched = 1;
    pad_mode(mux + 4, 0);
    if (!pulse || interrupted) { rc = 0; goto done; }
    struct request req = {.channel=1, .high=high_count, .total=111, .enable=1};
    if (ioctl(pwmfd, 1UL, &req)) { perror("PWM1 enable"); goto done; }
    if (regs[0x20/4] != 111 || regs[0x24/4] != high_count ||
        regs[0x28/4] != 10 || regs[0x2c/4] != 5) {
        fputs("PWM1 readback mismatch; returning to off.\n", stderr); goto done;
    }
    if (!interrupted) {
        pad_mode(mux + 4, 1);
        if (lease) {
            puts("READY");
            fflush(stdout);
            while (!interrupted) {
                struct pollfd pfd = {.fd=STDIN_FILENO, .events=POLLIN};
                int ready = poll(&pfd, 1, 4000);
                if (ready < 0 && errno == EINTR) continue;
                if (ready <= 0) { fputs("Lease expired or poll failed; off.\n", stderr); rc=1; goto done; }
                char heartbeat[64];
                ssize_t n = read(STDIN_FILENO, heartbeat, sizeof heartbeat);
                if (n <= 0) break;
            }
        } else {
            struct timespec delay = {.tv_sec=1};
            while (!interrupted && nanosleep(&delay, &delay)) {
                if (errno != EINTR) { perror("nanosleep"); goto done; }
            }
        }
    }
    rc = 0;
done:
    if (touched) {
        /* Disconnect PWM first; the GPIO latch was already set low. */
        pad_mode(mux + 4, 0);
        struct request off = {.channel=1};
        if (ioctl(pwmfd, 1UL, &off)) { perror("PWM1 disable"); rc = 1; }
        if (write_text("/sys/class/gpio/gpio4/value", "0\n")) rc = 1;
        if (regs[0x2c/4] != 0 || (mux[4] & 0x20f) != 0x200) {
            fputs("Off-state register readback mismatch\n", stderr); rc = 1;
        }
        if (!rc) puts("PWM1 disabled; pad in GPIO4 mode, GPIO commanded low.");
    }
    if (claimed && write_text("/sys/class/gpio/unexport", "4\n")) rc = 1;
    if (mux) munmap((void *)mux, (size_t)size);
    if (clock) munmap((void *)clock, (size_t)size);
    if (regs) munmap((void *)regs, (size_t)size);
    if (mem >= 0) close(mem);
    if (pwmfd >= 0) close(pwmfd);
    return interrupted ? 128 + interrupted : rc;
}
