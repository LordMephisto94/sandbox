CC ?= cc
CFLAGS ?= -O2
CPPFLAGS ?=
BUILD_DIR := build
SOURCE := src/white-led.c

.PHONY: all check clean
all: $(BUILD_DIR)/white-led

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/white-led: $(SOURCE) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -D_GNU_SOURCE $(CFLAGS) -Wall -Wextra -Werror -std=c11 $< -o $@

$(BUILD_DIR)/white-led-mock: tests/white-led-mock.c $(SOURCE) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -Wall -Wextra -Werror -std=c11 $< -o $@

check: $(BUILD_DIR)/white-led-mock
	$(BUILD_DIR)/white-led-mock
	sh tests/test-policy.sh
	python3 tests/test-service.py
	python3 tests/test-recovery.py
	python3 tests/test-supervisor.py
	python3 tests/test-layout.py

clean:
	rm -rf -- $(BUILD_DIR)
