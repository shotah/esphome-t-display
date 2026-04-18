# ---------------------------------------------------------------
# Makefile — LumaDeck consumer repo (LilyGo T-Display-S3 AMOLED)
#
# Wraps the manual flow from todo.md §P0.2:
#   cp secrets.example.yaml secrets.yaml   # edit wifi creds
#   esphome run device.yaml
#
# Quick start (one-time):
#   make init        # pulls lumadeck submodule + scaffolds secrets.yaml
#   make install     # installs esphome into a local pipenv (~200MB)
#   $EDITOR secrets.yaml
#   make run         # build + upload + tail logs
#
# Override the device file or the esphome runner from the command line:
#   make run DEVICE=other.yaml
#   make run ESPHOME=esphome              # bypass pipenv
#
# Recipes use python (not sh/awk/grep) so they work identically on
# Windows cmd, PowerShell, Git Bash, macOS, and Linux. Python ships
# with ESPHome, so it's a safe assumption on this repo.
# ---------------------------------------------------------------

DEVICE       ?= device.yaml
LUMADECK_URL ?= https://github.com/shotah/LumaDeck
ESPHOME      ?= pipenv run esphome
PYTHON       ?= python

.DEFAULT_GOAL := help

.PHONY: help init secrets submodule submodule-update install \
        config compile run flash upload logs clean check

help: ## Show this help
	@echo Targets:
	@echo   init             One-time setup: lumadeck submodule + secrets.yaml
	@echo   secrets          Create secrets.yaml from the template (if missing)
	@echo   submodule        Add the lumadeck git submodule (or init if present)
	@echo   submodule-update Pull latest LumaDeck and stage the version bump
	@echo   install          Install esphome into a local pipenv (~200MB)
	@echo   config           Validate $(DEVICE) without compiling
	@echo   compile          Compile firmware for $(DEVICE)
	@echo   run              Build + upload + tail logs
	@echo   flash            Alias for run
	@echo   upload           Upload an already-compiled binary (OTA if on wifi)
	@echo   logs             Tail device logs
	@echo   clean            Wipe the ESPHome build cache for $(DEVICE)
	@echo   check            Lightweight CI-style check (esphome config)
	@echo.
	@echo Variables: DEVICE=$(DEVICE)  ESPHOME=$(ESPHOME)

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
