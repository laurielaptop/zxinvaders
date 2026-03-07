ASM ?= z80asm
FUSE ?= fuse
ZESARUX ?= /Applications/ZEsarUX.app/Contents/MacOS/zesarux
BIN2TAP ?= bin2tap

SRC := src/main.z80
BUILD_DIR := build
DIST_DIR := dist

BIN := $(BUILD_DIR)/zxinvaders.bin
TAP := $(DIST_DIR)/zxinvaders.tap

.PHONY: all assemble package-tap run run-klive run-zesarux clean check check-tools bootstrap dirs

all: assemble

assemble: dirs check-assembler $(BIN)
	@echo "Built $(BIN)"

$(BIN): $(SRC) src/platform/video.z80 src/platform/input.z80 src/platform/timing.z80
	$(ASM) -I src -o $(BIN) $(SRC)

package-tap: assemble
	@mkdir -p $(DIST_DIR)
	@./tools/bin_to_tap.sh $(BIN) $(TAP) 32768 ZXINVADERS 32768

run: package-tap
	@./tools/run_fuse.sh $(TAP)

run-klive: package-tap
	@./tools/run_fuse.sh --klive $(TAP)

run-zesarux: package-tap
	@./tools/run_fuse.sh --zesarux $(TAP)

check: check-tools assemble
	@echo "Checks passed"

check-tools:
	@./tools/check_tools.sh

check-assembler:
	@if ! command -v $(ASM) >/dev/null 2>&1; then \
		echo "Missing assembler: $(ASM)"; \
		echo "Run: make bootstrap"; \
		exit 1; \
	fi

dirs:
	@mkdir -p $(BUILD_DIR) $(DIST_DIR)

bootstrap:
	@./tools/bootstrap_macos.sh

clean:
	@rm -rf $(BUILD_DIR)/* $(DIST_DIR)/*
	@echo "Cleaned build and dist outputs"
