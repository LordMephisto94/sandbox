/* Host-only hardware mock: exercise actual controller and failure cleanup. */
#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <stdarg.h>

static uint32_t pads[1024], clocks[1024], pwms[1024];
static int busy, bad_readback, signal_during_wait, low, exported, calls, enabled;
static const char *read_direction, *read_value, *read_polarity;
static int lease_poll_calls, lease_eof;
static unsigned expected_high;
static int fake_open(const char *p, int flags, ...)
{
    (void)flags; calls++;
    if (!strcmp(p,"/dev/pwm")) return 10;
    if (!strcmp(p,"/dev/mem")) return 20;
    if (!strcmp(p,"/sys/class/gpio/export")) return 30;
    if (!strcmp(p,"/sys/class/gpio/gpio4/direction")) return 31;
    if (!strcmp(p,"/sys/class/gpio/gpio4/value")) return 32;
    if (!strcmp(p,"/sys/class/gpio/unexport")) return 33;
    if (!strcmp(p,"/sys/class/gpio/gpio4/active_low")) return 34;
    assert(0); return -1;
}
static int fake_close(int fd) { (void)fd; return 0; }
static ssize_t fake_read(int fd, void *buf, size_t size)
{
    if (fd==STDIN_FILENO) {
        if (lease_eof) return 0;
        assert(size); ((char *)buf)[0]='H';return 1;
    }
    if (!exported) { errno=ENOENT; return -1; }
    const char *s=fd==31 ? read_direction : fd==32 ? read_value : read_polarity;
    assert(strlen(s)<size); memcpy(buf,s,strlen(s)); return (ssize_t)strlen(s);
}
static int fake_fstat(int fd, struct stat *s) { assert(fd==10); s->st_mode=S_IFCHR; return 0; }
static ssize_t fake_write(int fd, const void *buf, size_t n)
{
    const char *s=buf;
    if (fd==30) {
        if (busy) { errno=EBUSY; return -1; }
        assert(!strcmp(s,"4\n")); exported=1;
    } else if (fd==31) {
        assert(exported && !strcmp(s,"low\n")); low=1;
    } else if (fd==32) {
        assert(exported && !strcmp(s,"0\n")); low=1;
    } else if (fd==33) {
        assert(exported); exported=0;
    } else assert(0);
    return (ssize_t)n;
}
static void *fake_mmap(void *a,size_t n,int p,int f,int fd,off_t off)
{
    (void)a;(void)p;(void)f;assert(fd==20 && n==4096);
    if (off==0x100c0000) return pads;
    if (off==0x12010000) return clocks;
    assert(off==0x12080000); return pwms;
}
static int fake_munmap(void *a,size_t n) { (void)a;(void)n;return 0; }
static long fake_sysconf(int n) { assert(n==_SC_PAGESIZE);return 4096; }
static int fake_sigaction(int s,const struct sigaction *a,struct sigaction *b)
{ (void)s;(void)a;(void)b;return 0; }
static int fake_ioctl(int fd,unsigned long command,...)
{
    va_list ap; va_start(ap,command); const uint8_t *r=va_arg(ap,const void *);va_end(ap);
    assert(fd==10 && command==1 && r[0]==1);
    assert(low && exported && (pads[4]&15)==0);
    if(r[12]) {
        uint32_t high,total;memcpy(&high,r+4,4);memcpy(&total,r+8,4);
        assert(high==expected_high && total==111);
        pwms[8]=total;pwms[9]=bad_readback?7:high;pwms[10]=10;pwms[11]=5;enabled++;
    } else pwms[11]=0;
    return 0;
}
static int fake_nanosleep(const struct timespec *a,struct timespec *b);
static int fake_poll(struct pollfd *p,nfds_t n,int timeout)
{
    assert(n==1 && p->fd==0 && timeout==4000);
    assert(pads[4]==0x1001 && pwms[11]==5);
    return lease_poll_calls++ == 0 ? 1 : 0;
}
#define main controller_main
#define open fake_open
#define close fake_close
#define fstat fake_fstat
#define write fake_write
#define read fake_read
#define mmap fake_mmap
#define munmap fake_munmap
#define sysconf fake_sysconf
#define sigaction fake_sigaction
/* Struct tag must also exist under the function-like macro; avoid replacing it. */
#undef sigaction
#define sigaction(...) fake_sigaction(__VA_ARGS__)
#define ioctl fake_ioctl
#define nanosleep fake_nanosleep
#define poll fake_poll
#include "../src/white-led.c"
#undef main
static int fake_nanosleep(const struct timespec *a,struct timespec *b)
{
    (void)b;assert(a->tv_sec==1 && pads[4]==0x1001 && pwms[11]==5);
    if(signal_during_wait) { stop(SIGTERM);errno=EINTR;return -1; }
    return 0;
}
static void reset(void)
{
    memset(pads,0,sizeof pads);memset(clocks,0,sizeof clocks);memset(pwms,0,sizeof pwms);
    pads[4]=0x1000;clocks[0x1bc/4]=0x282;
    pwms[0]=200;pwms[1]=57;pwms[3]=5;
    busy=bad_readback=signal_during_wait=low=exported=calls=enabled=interrupted=0;
    read_direction="in\n";read_value="0\n";read_polarity="0\n";
    lease_poll_calls=lease_eof=0;
    expected_high=6;
}
static int run(char *action)
{ char *args[]={"white-led-test","--apply",action,NULL};return controller_main(3,args); }
static int reuse_run(char *action)
{ char *args[]={"white-led-test","--apply","--reuse-gpio4",action,NULL};return controller_main(4,args); }
static void check_off(void)
{
    assert(pads[4]==0x1200 && pwms[11]==0 && low && !exported);
    assert(pwms[0]==200 && pwms[1]==57 && pwms[2]==0 && pwms[3]==5);
    assert(clocks[0x1bc/4]==0x282);
}
int main(void)
{
    reset();char *dry[]={"white-led-test","test",NULL};
    assert(controller_main(2,dry)==0 && !calls);
    reset();assert(run("test")==0 && enabled==1);check_off();
    reset();assert(run("off")==0 && !enabled);check_off();
    reset();busy=1;assert(run("test")==1 && !enabled && pads[4]==0x1000);
    reset();bad_readback=1;assert(run("test")==1);check_off();
    reset();signal_during_wait=1;assert(run("test")==128+SIGTERM);check_off();
    reset();pads[4]=0x1002;assert(run("test")==1 && !exported && !enabled);
    reset();clocks[0x1bc/4]=0;assert(run("test")==1 && !exported && !enabled);
    reset();pwms[11]=5;assert(run("test")==1 && !exported && !enabled);
    reset();exported=1;assert(reuse_run("test")==0 && exported && enabled==1);
    exported=0;check_off();
    reset();exported=1;read_direction="out\n";
    assert(reuse_run("off")==0 && exported && !enabled);exported=0;check_off();
    reset();exported=1;read_polarity="1\n";
    assert(reuse_run("test")==1 && exported && !enabled && !low && pads[4]==0x1000);
    reset();exported=1;read_value="1\n";
    assert(reuse_run("test")==1 && exported && !enabled && !low && pads[4]==0x1000);
    reset();assert(reuse_run("test")==1 && !exported && !enabled);
    reset();exported=1;signal_during_wait=1;
    assert(reuse_run("test")==128+SIGTERM && exported);exported=0;check_off();
    reset();exported=1;assert(reuse_run("lease")==1 && exported && lease_poll_calls==2);
    exported=0;check_off();
    reset();exported=1;lease_eof=1;assert(reuse_run("lease")==0 && exported);
    exported=0;check_off();
    reset();expected_high=22;
    char *bright[]={"white-led-test","--apply","--high-count","22","test",NULL};
    assert(controller_main(5,bright)==0 && pwms[9]==22);check_off();
    reset();expected_high=110;bright[3]="110";
    assert(controller_main(5,bright)==0 && pwms[9]==110);check_off();
    const char *invalid[]={"0","1","111","-1","2.5","999999999999999999999999"};
    for(unsigned i=0;i<sizeof invalid/sizeof invalid[0];i++) {
        reset();bright[3]=(char *)invalid[i];
        assert(controller_main(5,bright)==2 && !calls);
    }
    puts("25 controller scenarios passed");return 0;
}
