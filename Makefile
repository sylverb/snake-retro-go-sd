# Retro-Go SD — Snake GWHB homebrew
#
#   make PROJECT_KIND=homebrew
#   make host             — Linux/macOS SDL binary (same src/main.c)
#   make host HOST_SDL=3  — same with SDL3
#   make docker PROJECT_KIND=homebrew
#
# Upstream game: https://github.com/slipperstree/game-and-watch-snake
# Verbose compiler lines: make V=

#######################################
# Project identity
#######################################
PROJECT_KIND ?= homebrew

CORE_NAME  := snake
CORE_ENTRY := app_main

CORE_C_SOURCES := \
src/main.c \
src/snake/Src/common.c \
src/snake/Src/control.c \
src/snake/Src/display.c \
src/snake/Src/embSnake.c \
src/snake/Src/embSnakeDevice.c \
src/snake/Src/font.c \
src/snake/Src/gw_draw.c \
src/snake/Src/key.c \
src/snake/Src/myMathUtil.c \
src/snake/Src/saveData.c \
src/snake/Src/snake_platform.c

CORE_C_INCLUDES := \
-Isrc/snake/Inc

GNW_CORE_SDK ?= sdk
BUILD_DIR ?= build/$(PROJECT_KIND)

#######################################
# Kind-specific compile defs + packing
#######################################
ifeq ($(PROJECT_KIND),core)
$(error This project is a homebrew only — use PROJECT_KIND=homebrew)

else ifeq ($(PROJECT_KIND),homebrew)
CORE_C_DEFS := \
-DPROJECT_KIND_HOMEBREW=1

PACKED_BIN := Snake.bin
COVER_JPG  := $(BUILD_DIR)/cover.jpg

else
$(error PROJECT_KIND must be 'homebrew' (got '$(PROJECT_KIND)'))
endif

include $(GNW_CORE_SDK)/Makefile

PACK_HOMEBREW := $(GNW_CORE_SDK)/tools/pack_homebrew.py

#######################################
# Packed header version
#######################################
# gwhb_meta_t only stores major.minor.patch (0..255).
# CORE_VERSION is the full git describe string passed to the packer; it
# extracts the leading vX.Y.Z (NOTAG / missing tags → 0.0.0).
# Override: make CORE_VERSION=v1.2.3
CORE_VERSION ?= $(shell git describe --tags --dirty 2>/dev/null || echo NOTAG)

#######################################
# Pack
#######################################
.PHONY: pack cover

.PHONY: cover
cover: $(COVER_JPG)

# Homebrew cover: 128×96 (within gui.c COVER_MAX 186×100) and ≤10 KiB.
$(COVER_JPG): src/assets/cover_src.jpg
	@mkdir -p $(BUILD_DIR)
	python3 -c "from pathlib import Path; from PIL import Image; \
img=Image.open('src/assets/cover_src.jpg').convert('RGB'); \
img.thumbnail((128,96)); \
canvas=Image.new('RGB', (128,96), (8,16,24)); \
x=(128-img.width)//2; y=(96-img.height)//2; \
canvas.paste(img, (x,y)); \
canvas.save('$(COVER_JPG)', 'JPEG', quality=80, optimize=True); \
sz=Path('$(COVER_JPG)').stat().st_size; \
assert sz <= 10*1024, f'cover too big: {sz}'"

pack: $(TARGET_BIN) $(COVER_JPG)
	$(V)$(ECHO) [ PACK GWHB ] $(PACKED_BIN) version=$(CORE_VERSION)
	$(V)python3 $(PACK_HOMEBREW) \
		--elf $(TARGET_ELF) --bin $(TARGET_BIN) \
		--name "Snake" --version "$(CORE_VERSION)" \
		--cover $(COVER_JPG) \
		--out $(PACKED_BIN)

all: pack

# Read-only helpers for CI / scripts (make print-PROJECT_KIND, etc.).
.PHONY: print-PROJECT_KIND print-PACKED_BIN print-CORE_NAME print-DOCKER_IMAGE \
	print-TARGET_ELF print-TARGET_MAP print-CORE_VERSION
print-PROJECT_KIND:
	@echo $(PROJECT_KIND)
print-PACKED_BIN:
	@echo $(PACKED_BIN)
print-CORE_NAME:
	@echo $(CORE_NAME)
print-DOCKER_IMAGE:
	@echo $(DOCKER_IMAGE)
print-TARGET_ELF:
	@echo $(TARGET_ELF)
print-TARGET_MAP:
	@echo $(BUILD_DIR)/$(CORE_NAME)_core.map
print-CORE_VERSION:
	@echo $(CORE_VERSION)

clean::
	$(V)rm -f $(PACKED_BIN)
	$(V)rm -f $(COVER_JPG)

#######################################
# Docker (same image as firmware repo)
#######################################
.PHONY: docker docker_pull docker_shell

RELEASE_VERSION ?= v1.5
DOCKER_REPOSITORY ?= sylverb/retro-go-sd-builder
DOCKER_IMAGE ?= $(DOCKER_REPOSITORY):$(RELEASE_VERSION)

DOCKER_TTY_FLAG := $(shell if [ -t 0 ]; then echo -it; else echo; fi)
DOCKER_USER := $(shell id -u):$(shell id -g)
DOCKER_RUN := docker run --rm $(DOCKER_TTY_FLAG) \
	--user $(DOCKER_USER) \
	-v "$(CURDIR):/opt/workdir" \
	-w /opt/workdir \
	$(DOCKER_IMAGE)

docker:
	$(V)$(ECHO) "[ DOCKER ]" $(DOCKER_IMAGE) "PROJECT_KIND=$(PROJECT_KIND)"
	$(V)$(DOCKER_RUN) make --no-print-directory -j$$(nproc) PROJECT_KIND=$(PROJECT_KIND)

docker_pull:
	$(V)$(ECHO) "[ PULL ]" $(DOCKER_IMAGE)
	$(V)docker pull $(DOCKER_IMAGE)

docker_shell:
	$(DOCKER_RUN) bash

#######################################
# Host SDL (Linux / macOS)
#######################################
include host/Makefile.host
