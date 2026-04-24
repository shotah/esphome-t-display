# Waveshare ESP32-S3-Touch-LCD-1.85C — bring-up notes

Everything board-specific we've learned trying to get this panel
lit. **All of this lives in the consumer repo on purpose** —
LumaDeck (the upstream UI package) is supposed to know nothing about
specific hardware. When in doubt about anything below, the
authoritative source is Waveshare's own reference firmware,
vendored as a submodule:

* [`references/waveshare-esp32-s3-touch-lcd-1.85c/`](../references/waveshare-esp32-s3-touch-lcd-1.85c/)
  ([upstream](https://github.com/waveshareteam/ESP32-S3-Touch-LCD-1.85C))

If our YAML disagrees with their working ESP-IDF / Arduino code,
**they are right**. Update our YAML to match and add a citation
comment.

---

## Hardware quick-reference

* **MCU:** ESP32-S3R8 (16 MB Flash, 8 MB octal PSRAM)
* **USB:** Type-C → ESP32-S3 native USB-Serial/JTAG (GPIO19/20).
  No CH340/CP2102 bridge.
* **Display:** ST77916 360×360 round AMOLED, QSPI
* **Touch:** CST816 (capacitive, I²C)
* **GPIO expander:** TCA9554PWR @ I²C 0x20 — drives `LCD_RST`,
  `TP_RST`, SD card CS, and RTC interrupt
* **Audio (BOX variant):** PCM5101 I²S DAC + 4Ω 5W speaker
* **Battery (BOX-with-battery variant):** 3.7V Li, charge-managed
* **Other:** PCF85063 RTC, microphone, TF slot, BOOT/RESET buttons

Pin map: see Waveshare wiki <https://www.waveshare.com/wiki/ESP32-S3-Touch-LCD-1.85C>
or the `Display_ST77916.h` / `TCA9554PWR.h` headers in the reference
submodule.

---

## Footguns we hit (in order of pain)

### 1. Logger silently sinks if `hardware_uart:` isn't `USB_SERIAL_JTAG`

By default ESPHome targets UART0 (GPIO43/44, side header only).
The USB-C cable goes to the chip's **built-in** USB-Serial/JTAG
peripheral on GPIO19/20, which is a different uart. Default config
flashes a working device that prints nothing visible.

Fix in `waveshare-1.85c.yaml`:

```yaml
logger:
  hardware_uart: USB_SERIAL_JTAG
  level: ${log_level}
```

Status: **fixed in our YAML.** Pushed upstream as P0 #2 in
`lumadeck.todo.md`.

### 2. Wrong ST77916 init sequence

Espressif ships an `esp_lcd_st77916` driver with a generic
`vendor_specific_init_default[]` array. ESPHome's `model: CUSTOM`
expects you to feed it those bytes. We did.

The bytes are wrong for this board.

Waveshare's own reference firmware
([`Display_ST77916.cpp`](../references/waveshare-esp32-s3-touch-lcd-1.85c/Arduino/examples/01_lvgl_example/Display_ST77916.cpp))
ships with **two different init sequences** and reads chip register
`0x04` at boot to pick between them:

* Pattern `0x00 0x7F 0x7F 0x7F` → no override (uses Espressif default)
* Pattern `0x00 0x02 0x7F 0x7F` → uses `vendor_specific_init_new[]`

The `vendor_specific_init_new[]` sequence is **completely different**
from the Espressif default — different gamma curves, different bias
voltages, different first commands (`0xF0=0x28` vs `0xF0=0x08`).
Boards manufactured 2025+ use the new sequence; the Espressif default
won't initialise the panel.

Fix in our YAML: replace the entire `init_sequence:` block with the
bytes from `vendor_specific_init_new[]`. Done.

### 3. Wrong color order

Waveshare's reference uses `LCD_RGB_ELEMENT_ORDER_RGB` (line 326 of
`Display_ST77916.cpp`). We had `color_order: bgr`. Flipped to `rgb`.
If colors look swapped after first light, swap back.

### 4. SPI clock too slow

ESPHome's `qspi_dbi` defaults to ~10 MHz. Waveshare's reference
runs at 80 MHz (`ESP_PANEL_LCD_SPI_CLK_HZ`). 8× slower might still
work but isn't what the panel was characterised against. Set
`data_rate: 80MHz` on the display block.

### 5. Audio "plays" but no sound — GPIO15 is a PA enable

PCM5101 is just a DAC; the analog amplifier downstream of it has its
own enable line on **GPIO15**. Without driving it HIGH, ESPHome's
`speaker:` will happily log `Started → Stopped` and the I2S bus will
be active but nothing reaches the speaker.

Source: [`Audio_Driver.c::Audio_PA_EN()`](../references/waveshare-esp32-s3-touch-lcd-1.85c/ESP-IDF/ESP32-S3-Touch-LCD-1.85C-Test/ESP32-S3-Touch-LCD-1.85C-Test/main/Audio_Driver/Audio_Driver.c)
toggles GPIO15 HIGH right before each `audio_play_*()` call and back
LOW after.

Fix in our YAML — keep PA enabled all the time (negligible idle
draw, simpler than gating per-play):

```yaml
switch:
  - platform: gpio
    pin: GPIO15
    id: lum_audio_pa_enable
    name: "${device_friendly} Audio Amp"
    restore_mode: ALWAYS_ON
```

If you ever care about battery life, turn it off when the speaker is
idle (wire to `speaker.on_state` events).

**Note on conflicting wiki info:** the Waveshare wiki lists
`MIC_SCK = GPIO15` under the MIC pinout. Both can't be true on the
BOX variant — the reference firmware authoritatively uses GPIO15 as
PA enable, so trust the firmware. The wiki may be describing an
older revision or a different SKU.

**Battery is not required.** USB-C provides 5V → MP1605 buck →
3.3V, which powers everything including the audio amp. The 3.7V Li
battery is for portable / cable-less use only.

### 6. `LCD_RST` and `TP_RST` aren't real GPIOs

They're on the TCA9554 expander at EXIO2 (LCD) and EXIO1 (touch).
ESPHome handles this via the `pca9554` component (which covers both
PCA9554 and TCA9554 — same command interface). Component name in
ESPHome YAML is `pca9554:`, **not** `tca9554:`, even though every
schematic and Waveshare wiki page says "TCA9554".

```yaml
pca9554:
  - id: lum_io_expander
    address: 0x20
    i2c_id: bus_a

display:
  - platform: qspi_dbi
    reset_pin:
      pca9554: lum_io_expander
      number: 2          # EXIO2 = LCD_RST
      mode:
        output: true
      inverted: true     # active low
```

### 7. `make logs` interactive prompt eats the boot section

`esphome logs` shows a `[1] COM4 / [2] OTA` menu. By the time you
type `1`, boot is done and the `[C]` config-dump lines have already
flushed. Use `make listen` (raw pyserial miniterm) instead — it
opens the port immediately with no prompt and survives brief USB
re-enumerations on reset.

### 8. Reset on USB-Serial/JTAG drops the COM port for ~1s

Tapping RESET cycles the USB peripheral. Windows briefly loses COM4,
then it reappears. Any open serial handle (including
`make listen` / `make logs`) goes stale. Workflow that works:

1. Hit RESET on the board (waits ~1s while USB re-enumerates)
2. Run `make listen` immediately
3. Catch the boot section partway through

Or unplug and replug the USB-C cable with `make listen` already
running — same effect.

### 9. Watch the submodule pointer when adding *other* submodules

If you `git submodule add` something else (e.g. the `references/`
vendor SDK), it can silently roll back your `lumadeck/` pointer to
its previously-pinned commit even though the upstream `main` has
new work. After any `git submodule add`, run `git submodule status`
and check that `lumadeck` is still where you expected it. If not:

```bash
cd lumadeck && git pull origin main && cd ..
git add lumadeck && git commit -m "bump LumaDeck"
```

Cost us a debug round when our consumer YAML referenced
`lumadeck/packages/backlight.yaml` but the submodule had reverted
to a commit before that file existed.

---

## First-light debug workflow

Until the panel actually shows pixels, lean on the audio chime as
an out-of-band "is the device alive?" signal. Our YAML wires
`lum_notify_chime` to:

* `esphome.on_boot priority: -100` (after delay 2s) — fires once
  per successful boot.
* `binary_sensor.lum_boot_btn on_press:` — fires on every BOOT
  button press.

Decision tree from a fresh flash + `make listen`:

* **Beep on boot, beep on button** — device healthy. Bug is narrowly
  in display land. Try (in order):
  1. Flip `color_order: bgr` ↔ `rgb`
  2. Flip `invert_colors: false` ↔ `true`
  3. Drop SPI `data_rate` to `40MHz` or `20MHz`
  4. Look for `[E]` lines from `display.qspi_dbi`
* **Beep on boot, no beep on button** — boot button GPIO ISR or
  nav script chain is broken. Display debug can wait.
* **No boot beep, beep on button** — `on_boot` priority issue;
  setup completed but `on_boot -100` didn't fire.
* **No beeps at all** — crashing during component setup. Capture
  full boot log via `make listen` and look for the last `[I]` line
  before silence — that names the component that crashed.
* **No beeps, but logs show LVGL drawing** — speaker is wired
  wrong (check I2S pins) or `speaker:` block has a typo.

---

## Heartbeat logging

ESPHome's main loop is silent by default — components only log when
something happens. That makes it hard to tell whether a quiet device
is actually running or has wedged.

Our YAML carries an `interval:` block that prints a heartbeat every
5s with uptime + free heap:

```text
[I][main:...]: [heartbeat] uptime=12s  free_heap=178KB
[I][main:...]: [heartbeat] uptime=17s  free_heap=178KB
```

If the heartbeats stop, the main loop is blocked. If they keep
coming but free_heap is shrinking, something's leaking. Drop the
`interval:` block once you don't need it anymore — it's debug
scaffolding.

## Useful boot log markers to look for

`make listen` then RESET. The lines that tell us things actually
worked:

```text
ESP-ROM:esp32s3-...                              <- ROM bootloader
I (xxx) esp_psram: SPI SRAM memory test OK       <- PSRAM init (CRITICAL: needed for LVGL FB)
[I][i2c.idf:...]: Scanning i2c bus for active devices...
[I][i2c.idf:...]: Found i2c device at address 0x20    <- TCA9554 (CRITICAL: no panel reset without it)
[I][i2c.idf:...]: Found i2c device at address 0x15    <- CST816 touch
[I][i2c.idf:...]: Found i2c device at address 0x51    <- PCF85063 RTC
[C][pca9554:...]: PCA9554:
[C][pca9554:...]:   Address: 0x20
[C][display.qspi_dbi:...]: QSPI_DBI Display
[C][light:...]: Light 'Waveshare 1.85 Round Backlight'
[C][lvgl:...]: LVGL:
```

Anything starting with `[E]` trumps everything else — that's an
explicit failure. Paste it into chat and we'll fix the right thing
instead of guessing.

---

## When to update this doc

* Once first light works: lock in the actual `color_order` /
  `invert_colors` / `data_rate` settings that worked, and delete the
  "untested" caveats from `waveshare-1.85c.yaml`'s header.
* Whenever a Waveshare firmware update changes the init sequence in
  `references/`, re-bump the submodule and re-translate the bytes.
* Whenever ESPHome ships native `model: ST77916` for `qspi_dbi`,
  delete the giant `init_sequence:` block and just use the model.

---

## Cross-references

* [`waveshare-1.85c.yaml`](../waveshare-1.85c.yaml) — our consumer YAML.
* [`references/README.md`](../references/README.md) — what's in the
  vendor reference submodule and which files matter.
* [`lumadeck.todo.md`](../lumadeck.todo.md) — items we want pushed
  upstream into LumaDeck (UI-layer only; nothing board-specific).
