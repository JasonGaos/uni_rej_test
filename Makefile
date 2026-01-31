# Makefile for rej_uniform_asm test
# Works on both Linux (AArch64) and macOS (ARM64)

# Detect OS
UNAME_S := $(shell uname -s)

# Compiler settings
CC = gcc
AS = gcc
CFLAGS = -Wall -Wextra -O2 -g
ASFLAGS = -Wall -g
LDFLAGS =

# Platform-specific flags
ifeq ($(UNAME_S),Linux)
    # Linux - no special flags needed for AArch64
    CFLAGS += -march=armv8-a
    ASFLAGS += -march=armv8-a
else ifeq ($(UNAME_S),Darwin)
    # macOS
    CFLAGS += -arch arm64
    ASFLAGS += -arch arm64
    LDFLAGS += -arch arm64
endif

# Include paths
# Assembly includes ../../../common.h from src/ directory
INCLUDES = -I. -Isrc/include

# Source files
ASM_SRC = src/rej_uniform_asm.S
TABLE_SRC = src/rej_uniform_table.c
TEST_SRC = test.c

# Object files
ASM_OBJ = $(ASM_SRC:.S=.o)
TABLE_OBJ = $(TABLE_SRC:.c=.o)
TEST_OBJ = $(TEST_SRC:.c=.o)

# Output binary
TARGET = test_rej_uniform

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(ASM_OBJ) $(TABLE_OBJ) $(TEST_OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.S
	$(AS) $(ASFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(ASM_OBJ) $(TABLE_OBJ) $(TEST_OBJ) $(TARGET)

# Help target
help:
	@echo "Available targets:"
	@echo "  make          - Build the test executable"
	@echo "  make run      - Build and run the tests"
	@echo "  make clean    - Remove built files"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Platform: $(UNAME_S)"
