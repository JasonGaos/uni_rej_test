# Makefile for rej_uniform_asm test
# Works on both Linux (AArch64) and macOS (ARM64)
# Supports both NEON and SVE variants

# Detect OS
UNAME_S := $(shell uname -s)

# Variant selection: neon (default) or sve
VARIANT ?= neon

# Compiler settings
CC = gcc
AS = gcc
CFLAGS = -Wall -Wextra -O2 -g
ASFLAGS = -Wall -g
LDFLAGS =

# Platform-specific flags
ifeq ($(UNAME_S),Linux)
    # Linux AArch64
    CFLAGS += -march=armv8-a
    ASFLAGS += -march=armv8-a

    # Add SVE flags if building SVE variant
    ifeq ($(VARIANT),sve)
        CFLAGS += -march=armv8-a+sve -DHAVE_SVE
        ASFLAGS += -march=armv8-a+sve
    endif
else ifeq ($(UNAME_S),Darwin)
    # macOS ARM64
    CFLAGS += -arch arm64
    ASFLAGS += -arch arm64
    LDFLAGS += -arch arm64

    # Add SVE flags if building SVE variant (macOS 13+)
    ifeq ($(VARIANT),sve)
        CFLAGS += -DHAVE_SVE
    endif
endif

# Include paths
# Assembly includes ../../../common.h from src/ directory
INCLUDES = -I. -Isrc/include

# Source files
ASM_NEON_SRC = src/rej_uniform_asm.S
ASM_SVE_SRC = src/rej_uniform_asm_sve.S
TABLE_SRC = src/rej_uniform_table.c
TEST_SRC = test.c

# Object files
TABLE_OBJ = $(TABLE_SRC:.c=.o)
TEST_OBJ = $(TEST_SRC:.c=.o)

# Select assembly source based on variant
ifeq ($(VARIANT),sve)
    ASM_OBJ = $(ASM_SVE_SRC:.S=.o)
    TARGET_SUFFIX = _sve
else
    ASM_OBJ = $(ASM_NEON_SRC:.S=.o)
    TARGET_SUFFIX = _neon
endif

# Output binary with variant suffix
TARGET = test_rej_uniform$(TARGET_SUFFIX)

.PHONY: all clean run help neon sve

# Default target builds selected variant
all: $(TARGET)

# Build NEON variant
neon:
	$(MAKE) VARIANT=neon

# Build SVE variant
sve:
	$(MAKE) VARIANT=sve

# Build both variants
both: neon sve

$(TARGET): $(ASM_OBJ) $(TABLE_OBJ) $(TEST_OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.S
	$(AS) $(ASFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f src/*.o $(TABLE_OBJ) $(TEST_OBJ) test_rej_uniform test_rej_uniform_neon test_rej_uniform_sve

# Help target
help:
	@echo "Available targets:"
	@echo "  make          - Build $(VARIANT) variant (default: neon)"
	@echo "  make neon     - Build NEON variant"
	@echo "  make sve      - Build SVE variant"
	@echo "  make both     - Build both NEON and SVE variants"
	@echo "  make run      - Build and run the tests"
	@echo "  make clean    - Remove built files"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Current settings:"
	@echo "  Platform: $(UNAME_S)"
	@echo "  Variant: $(VARIANT)"
	@echo "  Target: $(TARGET)"
