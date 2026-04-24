# LumaDeck — Upstream TODO (consumer-driven)

Things this consumer repo discovered that genuinely belong **inside
LumaDeck** (the UI package), not in our consumer repo. The bar is:

> *"This change makes any LumaDeck consumer's life better, regardless
> of which board they're using."*

Hardware-specific stuff — pin maps, init sequences, panel quirks,
TCA9554 reset workarounds, sdkconfig tweaks — does **not** belong
upstream. That's the consumer repo's job. See
[`docs/waveshare-1.85c-bringup.md`](./docs/waveshare-1.85c-bringup.md)
for what we've learned about *this* board; nothing in that doc
should be pushed to LumaDeck.

> **Status:** all items below are open upstream. Each is real and
> reproducible (we tripped over them). The much larger list of
> "things we figured out about the Waveshare board" lives in our
> consumer-side bring-up doc, not here.

---

## P0 — bugs that break real consumers today

### 1. Five layouts are missing `climate_page`

`packages/nav.yaml` defines `nav_goto_climate` which calls
`lvgl.page.show: climate_page`. Layouts that don't declare the page
crash `esphome config` with:

```text
Couldn't find ID 'climate_page'. ... These IDs look similar:
"lights_page", "home_page", "media_page".
```

**Audit (verified against the pinned submodule commit):**

| Layout                          | climate_page declared? |
| ------------------------------- | :--------------------: |
| `wide_536x240.yaml`             |          yes           |
| `tall_240x536.yaml`             |          yes           |
| `wide_480x320.yaml`             |          yes           |
| `round_360.yaml`                |        **NO**          |
| `round_240.yaml`                |        **NO**          |
| `square_240.yaml`               |        **NO**          |
| `square_320.yaml`               |        **NO**          |
| `tall_240x320.yaml`             |        **NO**          |

**Proposed fix (least change):** add a placeholder `climate_page` to
each of the five layouts that's missing it, mirroring the existing
`settings_page` stub:

```yaml
- id: climate_page
  bg_color: ${bg}
```

**Discovered while:** `make waveshare-config` failed at
`nav_goto_climate` when our consumer YAML included `round_360.yaml`.
Worked around in `waveshare-1.85c.yaml` by adding `climate_page` to
the device's own `lvgl.pages:` block; deletable once this lands.

### 2. Default logger silently sinks on native-USB ESP32-S3 boards

Not a bug in LumaDeck per se, but a default that's silently wrong
for an entire class of modern hardware (any ESP32-S3 board where
USB-C is wired straight to the chip's USB-Serial/JTAG peripheral on
GPIO19/20 — Waveshare 1.85C and friends, NSPanel Pro, M5Stack CoreS3,
ESP32-S3-BOX, JC3636W518, etc.).

`packages/core.yaml` declares:

```yaml
logger:
  level: ${log_level}
```

…with no `hardware_uart:`, so ESPHome falls back to UART0 (GPIO43/44,
typically only on a side header). Result: consumer flashes a brand-
new device, runs `make ... logs`, sees `INFO Starting log output...`
followed by **nothing forever**, and concludes the firmware is
broken. It isn't — they're just listening on the wrong wire.

**Proposed fix:** `core.yaml` adds a `log_uart` substitution defaulting
to `DEFAULT`; `packages/board_esp32s3.yaml` overrides it to
`USB_SERIAL_JTAG` (which is correct for *most* modern S3 boards, and
boards with a CH340/CP2102 bridge can override back to `UART0`).

```yaml
# packages/core.yaml
substitutions:
  log_uart: "DEFAULT"
logger:
  level: ${log_level}
  hardware_uart: ${log_uart}
```

```yaml
# packages/board_esp32s3.yaml
substitutions:
  log_uart: "USB_SERIAL_JTAG"
```

**Discovered while:** every Waveshare bring-up attempt for the first
hour. The LilyGo build keeps working because UART0 is also exposed
on that board's CP2102, so the wrong-default-but-still-works case
masked the bug for the existing example.

---

## P1 — improvements

### 3. `make verify` should cross-check `nav.yaml` ↔ `layouts/*.yaml`

Mechanical: walk every `lvgl.page.show:` reference in `packages/nav.yaml`,
then for every `layouts/*.yaml`, assert each referenced page id is
declared. This is exactly the contract-checker pattern already in use
for themes — it just hasn't been extended to nav.

Once #1 is fixed by adding `climate_page` everywhere, this check
prevents the same class of bug from regressing when a new layout
gets added.

### 4. `docs/layout-contract.md` should formalise the page list

Today the contract says "define `home_page` (and optionally other
pages)". As bug #1 shows, "optionally" is a lie — `nav.yaml`
hard-codes references to all five pages, so any layout intended to
be paired with `nav.yaml` MUST declare:

* `home_page`
* `media_page`
* `lights_page`
* `climate_page`
* `settings_page`

**Proposed:** change "optionally" to "required if `packages/nav.yaml`
is included" (or just require all five unconditionally; cost is one
4-line stub per page). Update `layouts/_template.yaml` to scaffold
all five.

### 5. The `lumadeck.todo.md` STATUS header inside the submodule was aspirational, not real

(Meta-issue.) The submodule's own `lumadeck.todo.md` claims as of
the pinned commit that `packages/backlight.yaml`, `packages/audio.yaml`,
`widgets/notification_sound.yaml`, and the `climate_page` layout
fix all "landed upstream." None of them actually exist in the tree.
Our consumer YAML refactored to use those packages on the strength
of that doc and broke `esphome config` until reverted to inline
blocks.

**Proposed fix:** drop the "STATUS — landed upstream" header. If
items are planned but not done, mark them planned. Don't claim
done until the files exist and the tests pass.

(This isn't a bug a future consumer will hit at flash time; it's a
"don't let the documentation lie" hygiene fix. Mentioning it because
it cost us a debug round.)

---

## P2 — nice-to-haves (low priority, no consumer pain yet)

* **Backlight package** (`packages/backlight.yaml` — wraps LEDC
  output + monochromatic light; consumer supplies `${backlight_pin}`).
  Pattern reused on multiple boards; we have the inline version to
  copy. Generic, board-agnostic, belongs upstream. Not a P1 because
  the inline version is 14 lines and works.
* **Audio package** (`packages/audio.yaml` — wraps the I2S speaker
  sink; consumer declares the bus + `${audio_dout_pin}`). Same
  reasoning.
* **Notification-sound widget** (`widgets/notification_sound.yaml` —
  script that plays a sine chime through `lum_speaker`). Useful for
  any device with audio.

These three formed the basis of the previous round of this TODO and
the upstream `lumadeck.todo.md` (incorrectly) claimed they shipped.
They're cleanly extractable from our `waveshare-1.85c.yaml` whenever
someone wants to upstream them.

---

## How to migrate

1. **PR-1** — Layouts: add `climate_page` placeholder to the five
   layouts that lack it (#1). One edit per file, ~5 lines. **Highest
   impact: any consumer using a round/square layout with `nav.yaml`
   is broken until this lands.**
2. **PR-2** — `core.yaml` + `board_esp32s3.yaml` `log_uart`
   substitution (#2). Single-keyword change, biggest practical
   impact for first-time consumers on modern S3 boards.
3. **PR-3** — Layout contract update + nav↔layout validator (#3, #4).
   Pure docs + tests, no behaviour change.
4. **PR-4** — `lumadeck.todo.md` honesty pass (#5).
5. **PR-5** — Extract `packages/backlight.yaml`, `packages/audio.yaml`,
   `widgets/notification_sound.yaml` from the consumer YAML (#P2).
   Lowest priority — nothing's broken without them.

PRs 1, 2, 4 are zero-risk and probably mergeable in a single
afternoon. PR-1 alone unblocks every round/square consumer.
