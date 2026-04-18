# LumaDeck — TODO

A universal ESPHome + LVGL UI package. The goal: a consumer device repo
should be able to `!include` themes, layouts, and widgets without ever
editing this package.

> Hardware reference target (consumed in a separate repo):
> Waveshare ESP32-S3-Touch-LCD-1.85C (round 360x360, capacitive touch).
> Nothing in this package may hard-code that hardware.

---

## Status (v0.1.0 — 2026-04-18)

* **v0.1 MVP**: complete.
* **v0.2**: ~80% done. Touch gestures + on-hardware verification + icon
  font loading still open.
* **v0.3**: CLI shipped early. Scaling, preview, widget registry still
  open.
* **v1.0**: not started.
* **Quality gates**: `make check` (yamllint + `lumadeck validate-all` +
  `pytest`) is green. 32 tests passing.

Anything below that is unchecked is a real follow-up.

---

## Next up (priority order)

The right next step is **functional widget completeness**, not more
docs or examples. Docs cover the contracts we already have; we need
the widgets behind those contracts to actually work end-to-end.

### P0 — unblocks everything else

1. **Compile every example with `esphome config`.** If `!extend
   page-id` or any other LVGL merge pattern I used isn't valid in your
   ESPHome version, half the widgets will need restructuring. Until
   this is verified, every other widget task is built on assumption.

   Concrete steps (see
   [`docs/verifying-examples.md`](./docs/verifying-examples.md) for
   the full walkthrough):
   ```bash
   make install-verify   # one-time; pulls in ESPHome (~200MB)
   make verify           # runs `esphome config` against examples/*.yaml
   ```
   Or via pipenv: `pipenv install --dev && pipenv run verify`.

   Report failures with the file name + full error block and we can
   fix the widget structure in one pass. No hardware needed for this
   step — `esphome config` only validates YAML, it doesn't compile.

2. **Flash `examples/lilygo-t-display-amoled.yaml` to the LilyGo
   board.** This is the first real hardware target — pin map is
   taken verbatim from the upstream
   [LilyGo-AMOLED-Series](https://github.com/Xinyuan-LilyGO/LilyGo-AMOLED-Series)
   library and uses ESPHome's stock `qspi_dbi` (RM67162) and `cst816`
   platforms. From the consumer-repo template:
   ```bash
   cp -r consumer-repo-template/ ../my-amoled-firmware/
   cd ../my-amoled-firmware
   cp secrets.example.yaml secrets.yaml   # edit wifi creds
   esphome run device.yaml
   ```
   Anything that misbehaves on real LVGL on this panel becomes the
   highest-priority fix.

### P1 — functional gaps in the v0.1 widget set

2. **`analog_clock.yaml`** — wire per-second hand rotation via LVGL
   `transform_angle` updates. Currently the face renders but hands
   don't move.
3. **`media_card.yaml`** — add volume slider + mute button (people
   will expect this on a media remote).
4. **`album_art.yaml`** — implement HTTP fetcher pulling
   `${ha_media_player}.entity_picture`. Blocked on choosing an
   ESPHome image-loader pattern.
5. **`notification_toast.yaml`** — verify `lvgl.widget.update y: ...`
   actually animates. May need an explicit `lvgl.animate:` action.

### P2 — close out v0.2

6. **Touch gestures** in `packages/touch.yaml` — wire swipe-left /
   swipe-right to `nav_next_page` / `nav_prev_page` from
   `packages/nav.yaml`. Multi-page UIs aren't usable without this on
   touch panels.
7. **Icon font rendering** — `font_icon` is declared but no widget
   actually uses it. Add an icon glyph to `nav_tabs.yaml` buttons as
   the first consumer.
8. **Wire `${scale}` into widgets** — every layout declares a `scale`
   substitution but widgets use raw px. Pick 2-3 anchor sizes and
   multiply by `${scale}` in clock, media_card, ring_slider.

### P3 — new widgets

9. **`gauge.yaml`** — generic sensor → arc widget.
10. **`calendar_agenda.yaml`** — list of next N HA calendar events.

### P4 — polish (lowest priority)

* Per-widget READMEs (`widgets/<name>.md`)
* `docs/cli.md` full reference
* Screenshots / GIFs in README
* Markdown link checker in CI

---

## 0. Foundations

- [x] Define the public contract / "API" of the package
  - [x] List every `${substitution}` a theme MUST provide
        → `docs/theme-contract.md`
  - [x] List every `id:` a layout/widget MUST expose
        → `docs/layout-contract.md`, `docs/widget-contract.md`
  - [x] Document naming rules (snake_case, `lum_` prefix)
        → `docs/widget-contract.md`
  - [x] Add `CONTRIBUTING.md` describing the contract
- [x] Reconcile theme variable names — picked `bg/fg/accent/muted/...`,
      migrated `themes/*.yaml`, `widgets/clock.yaml`,
      `widgets/home_dashboard.yaml`.
- [x] Add a top-level `manifest.yaml` listing version, supported
      screen sizes, and required ESPHome version.
- [x] Add `CHANGELOG.md` and start tagging releases (`v0.1.0`).
- [x] Add `LICENSE` reference to README.
- [x] Add `.editorconfig` + `.yamllint.yaml` for consistency.

---

## 1. Repo hygiene

- [x] Fix README typos (`n- weather`, `n3. Wall thermostat panel`).
- [x] Remove duplicated/legacy "v0.1 Production Build" block from
      README.
- [x] Move long inline YAML in README into `docs/` and link to it.
- [x] Add GitHub issue + PR templates.
- [x] Add CI workflow (`.github/workflows/ci.yml`):
  - [x] `yamllint` on all `*.yaml`
  - [x] `lumadeck validate-all` against the contracts
  - [x] `pytest`
  - [x] `esphome config` dry-run against each `examples/*.yaml`
        (best-effort; examples include hardware-specific stubs)
  - [ ] Markdown link check on README/docs
- [x] Add `.gitattributes` for line endings.

---

## 2. Packages (`packages/`)

- [x] `core.yaml` — hardware-agnostic.
- [x] Make `core.yaml` board-agnostic
  - [x] Move `esp32:` block out to `packages/board_esp32s3.yaml`
  - [x] Allow consumer repo to choose `esp32` / `esp32c3` / `esp32s3`
  - [ ] Add `packages/board_esp32p4.yaml` (no devkit on hand to test)
- [x] `packages/fonts.yaml` — declares `font_xl/lg/md/sm/icon` from
      gfonts; sizes pulled from theme substitutions.
- [x] `packages/colors.yaml` — semantic color aliases on top of theme
      palette.
- [x] `packages/nav.yaml` — `script:` actions for page navigation.
- [x] `packages/ha.yaml` — Home Assistant service-call wrappers.
- [x] `packages/touch.yaml` — abstract touch-input flag globals.
- [x] `packages/display.yaml` — base LVGL config + reusable
      `style_definitions:`.

---

## 3. Themes (`themes/`)

- [x] `dark.yaml` — full theme contract.
- [x] `light.yaml`
- [x] `neon.yaml`
- [x] `themes/_template.yaml` — every key from the contract at its
      default value.
- [x] Document the required substitution keys
      (`docs/theme-contract.md`).
- [x] Add `themes/high_contrast.yaml` accessibility theme.
- [ ] Add seasonal / accent-only variants (optional, low priority).

---

## 4. Layouts (`layouts/`)

A layout = "how widgets are arranged on a given screen geometry".
It must NOT contain device-specific pins.

- [x] `round_360.yaml`
  - [x] Define safe drawing area (`safe_inset`) for circular masks
  - [x] Named regions: `region_top/center/bottom/left/right`
- [x] `square_240.yaml`
- [x] `wide_480x320.yaml`
- [x] `round_240.yaml`, `square_320.yaml`, `tall_240x320.yaml`
- [x] `layouts/_template.yaml` with the layout contract.
- [x] Introduce a scaling system: `${scale}` substitution declared by
      every layout.
- [ ] **Actually consume `${scale}` inside widgets** so font/size
      computations follow it. Today the substitution exists but
      widgets use raw px values.

---

## 5. Widgets (`widgets/`)

Each widget must:
- depend only on theme substitutions and documented ids
- be includable independently
- expose its own ids with a `lum_<name>_` prefix
- start with the contract header comment block

- [x] `clock.yaml` (rewritten on theme contract; date line; format
      configurable via substitutions).
- [x] `home_dashboard.yaml` (composite demo; updated).
- [x] `media_card.yaml` — title/artist + prev/play/next.
- [x] `weather.yaml`
- [x] `ring_slider.yaml` — brightness/volume; configurable target.
- [x] `icon_grid.yaml` — 6-slot scene grid; consumer wires `on_click`.
- [x] New widgets:
  - [x] `nav_tabs.yaml`
  - [x] `album_art.yaml` (placeholder card; see follow-up below)
  - [x] `thermostat.yaml`
  - [x] `light_button.yaml`
  - [x] `scene_button.yaml`
  - [x] `notification_toast.yaml` (top-layer overlay)
  - [x] `status_bar.yaml` (wifi/api/time)
  - [x] `progress_ring.yaml`
  - [x] `analog_clock.yaml` (face renders; hand rotation stubbed)
  - [ ] `calendar_agenda.yaml`
- [x] `widgets/_template.yaml`
- [ ] Per-widget README in `widgets/<name>.md` (or one `WIDGETS.md`).

### Widget follow-ups discovered during the build

See **Next up** at the top of this file for the priority ordering.

- [ ] **(P1)** `analog_clock.yaml` — wire actual per-second
      `transform_angle` updates; needs verification on hardware.
- [ ] **(P1)** `album_art.yaml` — implement HTTP fetcher pulling
      `${ha_media_player}.entity_picture`. Blocked on choosing an
      ESPHome image-loader pattern.
- [ ] **(P1)** `media_card.yaml` — add volume slider + mute button.
- [ ] **(P1)** `notification_toast.yaml` — verify
      `lvgl.widget.update y:` does what we expect on real LVGL
      (may need an explicit `lvgl.animate:` action).
- [ ] **(P3)** Add a generic `gauge.yaml` widget (sensor → arc).

---

## 6. Examples (`examples/`)

Examples are consumer-style YAMLs that prove the package works
end-to-end.

- [x] `round-clock.yaml`
- [x] `media-remote.yaml`
- [x] `room-controller.yaml`
- [x] `examples/waveshare-1.85c.yaml` — reference build for the
      hardware repo.
- [x] `examples/square-light-clock.yaml` — light theme + square
      layout, proves genericness.
- [ ] **Compile each example with `esphome config` against a real
      ESPHome version** to confirm `!extend page-id` and other LVGL
      merge patterns I used are valid.

---

## 7. Tools (`tools/`)

- [x] `tools/generate.py` — real CLI (`lumadeck new`):
  - [x] `lumadeck new <project> --screen round_360 --theme dark
        --widget clock ...`
  - [x] Emits a starter device YAML with correct includes
  - [x] Validates that the chosen layout / theme / widgets exist
- [x] `tools/lumadeck/validate.py` — `lumadeck validate <file>` and
      `lumadeck validate-all` enforce the theme/layout/widget
      contracts (with parametrised `pytest` coverage).
- [ ] `tools/preview/` — optional LVGL simulator preview (stretch).
- [x] Add `pyproject.toml` so tools install with `pip install -e .`.
- [x] Add `Pipfile` mirroring `pyproject.toml` for pipenv users.
- [x] Add `Makefile` task runner (`make help` for the catalogue).

---

## 8. Documentation

- [x] `docs/architecture.md`
- [x] `docs/theme-contract.md`
- [x] `docs/layout-contract.md`
- [x] `docs/widget-contract.md`
- [x] `docs/authoring-a-widget.md`
- [x] `docs/authoring-a-theme.md`
- [x] `docs/authoring-a-layout.md`
- [x] `docs/screen-sizes.md`
- [x] `docs/consumer-repo-guide.md`
- [ ] `docs/cli.md` — full reference for the `lumadeck` CLI
      (currently only documented via `--help`).

---

## 9. Roadmap alignment (from README)

### v0.1 (MVP) — DONE

- [x] core package solid + board-split
- [x] dark theme finalized
- [x] clock widget
- [x] media widget (basic)
- [x] round_360 layout usable end-to-end
- [x] one passing example: `examples/round-clock.yaml`

### v0.2 — mostly done

- [x] weather card
- [x] brightness ring slider
- [x] page navigation / nav tabs
- [x] `icon_grid` widget
- [ ] **Icon font** — `packages/fonts.yaml` declares `font_icon` from
      Material Symbols Outlined but no widget actually renders
      icon glyphs yet.
- [ ] **Touch gestures abstraction** — `packages/touch.yaml` defines
      activity flags only. Need swipe-to-page-next/prev wired through
      `packages/nav.yaml`.

### v0.3 — partial

- [x] YAML generator CLI (`lumadeck new`)
- [ ] live theme preview
- [ ] resolution auto-scaling (`${scale}` declared but unused — see
      §4 follow-up)
- [ ] widget registry (machine-readable index) — `manifest.yaml`
      provides a static list; a runtime/HTTP registry is still open.

### v1.0

- [ ] HACS-style installer
- [ ] community widget marketplace
- [ ] semver guarantees on the package contract

---

## 10. Out of scope for this repo (belongs in consumer repos)

- Display / touch driver pin assignments
- Secrets (`secrets.yaml`)
- Device-specific `esphome:` name, board, framework choice
- Hardware buttons / encoders specific to a device

---

## 11. Cross-cutting follow-ups

Items that don't fit a single section:

- [ ] Run every example through `esphome config` on a real ESPHome
      install (CI does this best-effort with `|| true`; needs a
      strict mode once the LVGL merge patterns are confirmed).
- [ ] Add a `tests/test_examples.py` that asserts each
      `examples/*.yaml` resolves all its substitutions.
- [ ] Add `pre-commit` config wiring `yamllint`, `ruff`, and
      `lumadeck validate-all`.
- [ ] Publish to PyPI once the contracts stabilise (v0.2+).
- [ ] Add screenshots / GIFs of each widget to the README.
