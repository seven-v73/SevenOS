CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -std=c11
BUILD_DIR ?= build

.PHONY: all clean

all: $(BUILD_DIR)/sevenbus-probe

$(BUILD_DIR)/sevenbus-probe: src/sevenbus_probe.c
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf $(BUILD_DIR)
