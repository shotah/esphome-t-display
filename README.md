# LumaDeck Consumer Repo Template

A starter for a **separate hardware repo** that consumes LumaDeck.
Copy this folder out of LumaDeck, rename it to your device, and you
have a self-contained ESPHome project that pulls all UI from the
upstream package.

```
my-panel-firmware/
├── README.md                 # describe the panel
├── secrets.yaml              # gitignored
├── secrets.example.yaml      # commit this template
├── .gitignore                # ignores secrets.yaml + .esphome/
├── my_panel.yaml             # your device YAML (edit this!)
└── lumadeck/                 # git submodule -> this repo
```

## Setup (5 min)

```bash
# 1. Copy this template out of LumaDeck and into a new repo
cp -r lumadeck/consumer-repo-template/  ../my-panel-firmware/
cd ../my-panel-firmware
git init && git add . && git commit -m "init"

# 2. Pull LumaDeck in as a submodule
git submodule add https://github.com/shotah/LumaDeck lumadeck
git commit -m "add LumaDeck submodule"

# 3. Copy the secrets template and fill it in
cp secrets.example.yaml secrets.yaml
# edit secrets.yaml with your wifi creds

# 4. Adjust device.yaml for your hardware (display/touch driver pins)
# 5. Build + flash
esphome run device.yaml
```

### Using the Makefile

If you have `make` and `pipenv` installed, the same flow boils down to:

```bash
make init       # add LumaDeck submodule + scaffold secrets.yaml
make install    # one-time: install esphome into a local pipenv
$EDITOR secrets.yaml
make run        # build + upload + tail logs
```

`make help` lists every target. Common overrides:

```bash
make run DEVICE=other.yaml      # point at a different device file
make run ESPHOME=esphome        # bypass pipenv, use system esphome
```

## Updating LumaDeck

```bash
cd lumadeck
git pull origin main
cd ..
git add lumadeck && git commit -m "bump LumaDeck"
```

Watch [LumaDeck's CHANGELOG](../CHANGELOG.md) for breaking contract
changes (they'll always be a major version bump).

## Already-working device files

`device.yaml` in this template ships with the LilyGo T-Display-S3
AMOLED config from `lumadeck/examples/lilygo-t-display-amoled.yaml`
pre-resolved against the submodule path. Swap in your own hardware
block if you're targeting a different panel.

## What goes in this repo vs LumaDeck

| Lives here (consumer repo)       | Lives in LumaDeck (the package)        |
| -------------------------------- | -------------------------------------- |
| `display:` driver + pins         | `packages/display.yaml` (LVGL base)    |
| `touchscreen:` driver + pins     | `packages/touch.yaml` (input flags)    |
| `i2c:`, `spi:`, GPIO buttons     | nothing hardware-specific              |
| `secrets.yaml`                   | nothing — secrets never live here      |
| Device-specific entity overrides | reusable themes, layouts, widgets      |

If you find yourself wanting to edit something inside `lumadeck/`,
that's almost always a sign it should be a substitution override or
a new widget upstream — open an issue.
