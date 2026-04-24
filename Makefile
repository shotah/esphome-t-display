# ---------------------------------------------------------------
# Makefile — LumaDeck consumer repo
#
# Drives both supported devices from a single repo:
#   * LilyGo T-Display-S3 AMOLED (1.91" 240x536) -> device.yaml
#   * Waveshare ESP32-S3-Touch-LCD-1.85C (round 360x360 + speaker)
#                                                -> waveshare-1.85c.yaml
#
# Quick start (one-time):
#   make init        # pulls lumadeck submodule + scaffolds secrets.yaml
#   make install     # installs esphome into a local pipenv (~200MB)
#   $EDITOR secrets.yaml
#
# Daily-driver, per device:
#   make lilygo               # build + upload + tail logs (LilyGo)
#   make waveshare            # build + upload + tail logs (Waveshare)
#   make lilygo-config        # validate the LilyGo YAML
#   make waveshare-logs       # tail Waveshare device logs
#   ...etc, see `make help`.
#
# Generic flow still works if you'd rather pass DEVICE explicitly:
#   make run DEVICE=device.yaml
#   make run DEVICE=waveshare-1.85c.yaml
#   make run ESPHOME=esphome              # bypass pipenv
#
# Recipes use python (not sh/awk/grep) so they work identically on
# Windows cmd, PowerShell, Git Bash, macOS, and Linux. Python ships
# with ESPHome, so it's a safe assumption on this repo.
# ---------------------------------------------------------------

# Default DEVICE keeps `make run` pointed at the LilyGo for backward
# compatibility — same behaviour as before the second board landed.
DEVICE         ?= device.yaml
LILYGO_YAML    ?= device.yaml
WAVESHARE_YAML ?= waveshare-1.85c.yaml
LUMADECK_URL   ?= https://github.com/shotah/LumaDeck
ESPHOME        ?= pipenv run esphome
PYTHON         ?= python
# `make listen` defaults. Override with `make listen PORT=COM7 BAUD=115200`.
PORT           ?= COM4
BAUD           ?= 115200

.DEFAULT_GOAL := help

.PHONY: help init secrets submodule submodule-update install \
        config compile run flash upload logs listen clean check \
        lilygo lilygo-config lilygo-compile lilygo-logs lilygo-clean \
        waveshare waveshare-config waveshare-compile waveshare-logs waveshare-clean

help: ## Show this help
	@echo Setup:
	@echo   init               One-time setup: lumadeck submodule + secrets.yaml
	@echo   secrets            Create secrets.yaml from the template (if missing)
	@echo   submodule          Add the lumadeck git submodule (or init if present)
	@echo   submodule-update   Pull latest LumaDeck and stage the version bump
	@echo   install            Install esphome into a local pipenv (~200MB)
	@echo.
	@echo LilyGo T-Display-S3 AMOLED ($(LILYGO_YAML)):
	@echo   lilygo             Build + upload + tail logs
	@echo   lilygo-config      Validate YAML without compiling
	@echo   lilygo-compile     Compile firmware
	@echo   lilygo-logs        Tail device logs
	@echo   lilygo-clean       Wipe the ESPHome build cache
	@echo.
	@echo Waveshare ESP32-S3-Touch-LCD-1.85C ($(WAVESHARE_YAML)):
	@echo   waveshare          Build + upload + tail logs
	@echo   waveshare-config   Validate YAML without compiling
	@echo   waveshare-compile  Compile firmware
	@echo   waveshare-logs     Tail device logs
	@echo   waveshare-clean    Wipe the ESPHome build cache
	@echo.
	@echo Generic (DEVICE override -- defaults to $(DEVICE)):
	@echo   config             Validate $(DEVICE) without compiling
	@echo   compile            Compile firmware for $(DEVICE)
	@echo   run                Build + upload + tail logs
	@echo   flash              Alias for run
	@echo   upload             Upload an already-compiled binary (OTA if on wifi)
	@echo   logs               Tail device logs (esphome's stream; misses boot)
	@echo   listen             Raw serial monitor on $(PORT) @ $(BAUD)
	@echo                      (better for catching boot; survives USB resets)
	@echo   clean              Wipe the ESPHome build cache for $(DEVICE)
	@echo   check              Lightweight CI-style check (esphome config)
	@echo.
	@echo Variables: DEVICE=$(DEVICE)  ESPHOME=$(ESPHOME)  PORT=$(PORT)  BAUD=$(BAUD)

# ---- one-time setup ------------------------------------------------

init: submodule secrets ## One-time setup: lumadeck submodule + secrets.yaml
	@echo.
	@echo Next: edit secrets.yaml, then run 'make install' and 'make run'.

secrets: ## Create secrets.yaml from the template (if missing)
	@$(PYTHON) -c "import os, shutil; \
		dst='secrets.yaml'; src='secrets.example.yaml'; \
		print('secrets.yaml already exists; not overwriting.') if os.path.exists(dst) \
		else (shutil.copyfile(src, dst), print('Created secrets.yaml -- edit it with your wifi creds.'))"

submodule: ## Add the lumadeck git submodule (or init if already present)
	@$(PYTHON) -c "import os, subprocess, sys; \
		registered = os.path.exists('.gitmodules') and 'lumadeck' in open('.gitmodules').read(); \
		cmd = ['git','submodule','update','--init','--recursive'] if registered \
		      else ['git','submodule','add','$(LUMADECK_URL)','lumadeck']; \
		print('Submodule already registered; syncing...') if registered \
		else print('Adding LumaDeck submodule from $(LUMADECK_URL)...'); \
		sys.exit(subprocess.call(cmd))"

submodule-update: ## Pull latest LumaDeck and stage the version bump
	cd lumadeck && git pull origin main
	git add lumadeck
	@echo Run: git commit -m "bump LumaDeck"

install: ## Install esphome into a local pipenv (~200MB)
	pipenv install esphome

# ---- daily-driver esphome wrappers --------------------------------

config: ## Validate $(DEVICE) without compiling
	$(ESPHOME) config $(DEVICE)

compile: ## Compile firmware for $(DEVICE)
	$(ESPHOME) compile $(DEVICE)

run: ## Build + upload + tail logs (the one you'll use 90% of the time)
	$(ESPHOME) run $(DEVICE)

flash: run ## Alias for `run`

upload: ## Upload an already-compiled binary (OTA if on wifi)
	$(ESPHOME) upload $(DEVICE)

logs: ## Tail device logs
	$(ESPHOME) logs $(DEVICE)

clean: ## Wipe the ESPHome build cache for $(DEVICE)
	$(ESPHOME) clean $(DEVICE)

check: config ## Lightweight CI-style check (just `esphome config` for now)

# `make listen` — raw serial monitor via pyserial's miniterm.
#
# Why this exists: `esphome logs` opens an interactive "[1] COM4 / [2] OTA"
# prompt, and on USB-Serial/JTAG boards (Waveshare 1.85C, anything with
# native ESP32-S3 USB) the chip finishes booting before the user picks
# an option, so the [C] config dump lines and I2C scan results are gone
# by the time logs attaches. miniterm opens the port immediately with no
# prompt, holds the handle through brief USB re-enumerations on reset,
# and gives you raw boot output. Exit with Ctrl-].
#
# Usage:
#   make listen                    # opens $(PORT) @ $(BAUD)
#   make listen PORT=COM7          # different port
#   make listen BAUD=921600        # different baud (rare; keep 115200)
listen: ## Raw serial monitor on $(PORT) @ $(BAUD) (Ctrl-] to exit)
	pipenv run python -m serial.tools.miniterm $(PORT) $(BAUD) --raw

# ---- per-device named targets -------------------------------------
# Each set of targets fixes DEVICE for its recipes via target-specific
# variable overrides — so `make lilygo-config` is exactly equivalent to
# `make config DEVICE=$(LILYGO_YAML)`, just less typing.

lilygo lilygo-config lilygo-compile lilygo-logs lilygo-clean: DEVICE := $(LILYGO_YAML)
waveshare waveshare-config waveshare-compile waveshare-logs waveshare-clean: DEVICE := $(WAVESHARE_YAML)

lilygo: ## LilyGo: build + upload + tail logs
	$(ESPHOME) run $(DEVICE)

lilygo-config: ## LilyGo: validate YAML without compiling
	$(ESPHOME) config $(DEVICE)

lilygo-compile: ## LilyGo: compile firmware
	$(ESPHOME) compile $(DEVICE)

lilygo-logs: ## LilyGo: tail device logs
	$(ESPHOME) logs $(DEVICE)

lilygo-clean: ## LilyGo: wipe the ESPHome build cache
	$(ESPHOME) clean $(DEVICE)

waveshare: ## Waveshare: build + upload + tail logs
	$(ESPHOME) run $(DEVICE)

waveshare-config: ## Waveshare: validate YAML without compiling
	$(ESPHOME) config $(DEVICE)

waveshare-compile: ## Waveshare: compile firmware
	$(ESPHOME) compile $(DEVICE)

waveshare-logs: ## Waveshare: tail device logs
	$(ESPHOME) logs $(DEVICE)

waveshare-clean: ## Waveshare: wipe the ESPHome build cache
	$(ESPHOME) clean $(DEVICE)
