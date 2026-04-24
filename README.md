# LumaDeck Consumer Repo Template

A starter for a **separate hardware repo** that consumes LumaDeck.
Copy this folder out of LumaDeck, rename it to your device, and you
have a self-contained ESPHome project that pulls all UI from the
upstream package.

```text
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
make lilygo     # build + upload + tail logs (LilyGo board)
# or:
make waveshare  # build + upload + tail logs (Waveshare board)
```

`make help` lists every target. Common overrides:

```bash
make run DEVICE=other.yaml      # point at any device file
make run ESPHOME=esphome        # bypass pipenv, use system esphome
```

### Supported devices

This repo ships with two ready-to-flash device YAMLs. Pick whichever
hardware you have on the bench — the LumaDeck UI layer is identical
across both, only the bottom hardware block differs.

**LilyGo T-Display-S3 AMOLED** (1.91" 240x536, RM67162 over QSPI)

- YAML: `device.yaml`
- Run with: `make lilygo`
- Driver status: stock ESPHome `qspi_dbi` `model: RM67162`. Just works.

**Waveshare ESP32-S3-Touch-LCD-1.85C** (round 360x360, ST77916, BOX speaker variant)

- YAML: `waveshare-1.85c.yaml`
- Run with: `make waveshare`
- Driver status: `model: CUSTOM` + TCA9554-routed reset. Expect a
  first-light debug pass on real hardware. See the header comment in
  `waveshare-1.85c.yaml` for what to tweak first.

Both YAMLs share the same `secrets.yaml`, the same `lumadeck/`
submodule, and the same Makefile workflow — every `make lilygo*`
target has a `make waveshare*` mirror (`-config`, `-compile`, `-logs`,
`-clean`).

> **Heads up on the Waveshare board:** as of ESPHome 2026.04 the
> ST77916 panel controller doesn't have a built-in driver, so the
> init sequence is hand-transcribed from
> [Espressif's reference driver](https://github.com/esp-arduino-libs/ESP32_Display_Panel/blob/master/src/drivers/lcd/port/esp_lcd_st77916.c).
> If first-light shows wrong colors or rotation, tweak `color_order:`
> and `invert_colors:` in `waveshare-1.85c.yaml` before assuming the
> init bytes are wrong.

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
pre-resolved against the submodule path. `waveshare-1.85c.yaml` does
the same for the Waveshare round 360x360 panel (BOX speaker variant).
Swap in your own hardware block — or add a third device YAML — if
you're targeting a different panel; the Makefile's generic `make run
DEVICE=...` target will pick it up without further changes.

## Per-device bring-up notes

When a device doesn't behave (panel won't light, touch is offset,
backlight stuck off, audio silent), the answer is almost always in
the manufacturer's own working firmware, not in LumaDeck. We vendor
those reference repos as git submodules under `references/` and
keep board-specific debug notes in `docs/`.

- [`docs/waveshare-1.85c-bringup.md`](./docs/waveshare-1.85c-bringup.md)
  — Waveshare ESP32-S3-Touch-LCD-1.85C: footguns, working init
  sequence source, first-light debug workflow.
- [`references/README.md`](./references/README.md) — index of the
  vendor reference submodules and which files in each one we
  actually look at.

If something behaves differently from what these notes describe, the
vendor reference is the source of truth — update the consumer YAML
and the doc to match it, not the other way around.

## What goes where

| Belongs in this consumer repo | Belongs upstream in LumaDeck |
| ----------------------------- | ---------------------------- |
| `device.yaml`, `waveshare-1.85c.yaml` (per-device YAML) | `packages/`, `themes/`, `layouts/`, `widgets/` (UI building blocks) |
| `secrets.yaml`, wifi creds, HA entity ids | nothing secret, nothing per-deployment |
| Board pin maps, init bytes, polarity flags, sdkconfig overrides | nothing board-specific |
| `references/` submodules (vendor SDKs we cross-check against) | nothing third-party |
| `docs/<board>-bringup.md` (per-board debug notes) | `docs/` for the UI contract, theme contract, etc. |
| `lumadeck.todo.md` (items we want pushed upstream) | n/a — that file is the channel into LumaDeck |

If you find yourself wanting to add a board-specific package to the
LumaDeck submodule, stop and put it here instead. LumaDeck is
deliberately ignorant of which board it's running on.

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
