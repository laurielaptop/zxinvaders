ASM ?= z80asm
FUSE ?= fuse
ZESARUX ?= /Applications/ZEsarUX.app/Contents/MacOS/zesarux
BIN2TAP ?= bin2tap

SRC := src/main.z80
PLATFORM_SRCS := $(wildcard src/platform/*.z80)
GAME_SRCS := $(wildcard src/game/*.z80)
BUILD_DIR := build
DIST_DIR := dist

BIN := $(BUILD_DIR)/zxinvaders.bin
TAP := $(DIST_DIR)/zxinvaders.tap

TEST_PIXELS_BIN := $(BUILD_DIR)/test_pixels.bin
TEST_PIXELS_TAP := $(DIST_DIR)/test_pixels.tap

DIAG_BIN := $(BUILD_DIR)/zxinvaders_diag.bin
DIAG_TAP := $(DIST_DIR)/zxinvaders_diag.tap

.PHONY: all assemble package-tap run run-klive run-zesarux dev monitor clean check check-tools bootstrap dirs
.PHONY: test-pixels run-test-pixels diag-pixels run-diag-pixels

all: assemble

assemble: dirs check-assembler $(BIN)
	@echo "Built $(BIN)"

$(BIN): $(SRC) src/constants.z80 $(PLATFORM_SRCS) $(GAME_SRCS)
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

dev: package-tap
	@./tools/dev.sh $(MONITOR_ARGS)

monitor:
	@echo "Connecting to ZEsarUX ZRCP on localhost:10000 ..."
	@echo "Make sure ZEsarUX is running (make run-zesarux in another terminal)."
	@python3 tools/zrcp_monitor.py $(MONITOR_ARGS)

test-pixels: dirs check-assembler $(TEST_PIXELS_BIN)
	@mkdir -p $(DIST_DIR)
	@./tools/bin_to_tap.sh $(TEST_PIXELS_BIN) $(TEST_PIXELS_TAP) 32768 PIXTEST 32768
	@echo "Built $(TEST_PIXELS_TAP)"

$(TEST_PIXELS_BIN): src/test_pixels.z80
	$(ASM) -I src -o $(TEST_PIXELS_BIN) src/test_pixels.z80

run-test-pixels: test-pixels
	@./tools/run_fuse.sh --zesarux $(TEST_PIXELS_TAP)

diag-pixels: dirs check-assembler $(DIAG_BIN)
	@mkdir -p $(DIST_DIR)
	@./tools/bin_to_tap.sh $(DIAG_BIN) $(DIAG_TAP) 32768 DIAGPIX 32768
	@echo "Built $(DIAG_TAP)"

$(DIAG_BIN): src/main_diag.z80
	$(ASM) -I src -o $(DIAG_BIN) src/main_diag.z80

run-diag-pixels: diag-pixels
	@./tools/run_fuse.sh --zesarux $(DIAG_TAP)

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
