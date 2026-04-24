# Vendor reference repos

Read-only third-party reference code, vendored as git submodules.
**Nothing in this directory is built, included, or shipped by our
firmware.** It exists so we can cross-reference our ESPHome YAML
against the manufacturer's working ESP-IDF / Arduino code when
something doesn't behave the way we expect.

When in doubt about init bytes, polarity, GPIO numbering, or boot
order, the manufacturer's own reference firmware is ground truth.

---

## `waveshare-esp32-s3-touch-lcd-1.85c/`

Source: <https://github.com/waveshareteam/ESP32-S3-Touch-LCD-1.85C>

Reference firmware (Arduino + ESP-IDF) for the **Waveshare
ESP32-S3-Touch-LCD-1.85C**, the board our `waveshare-1.85c.yaml`
device YAML targets. Pinned via git submodule; update with:

```bash
cd references/waveshare-esp32-s3-touch-lcd-1.85c
git pull origin main
cd ../..
git add references/waveshare-esp32-s3-touch-lcd-1.85c
git commit -m "bump waveshare reference"
```

### Files we actually look at

The submodule is large (~4400 files including the full LVGL Arduino
library tree). The handful that matter for our ESPHome bring-up:

#### `Arduino/examples/01_lvgl_example/Display_ST77916.cpp`

The ST77916 init sequence (`vendor_specific_init_new[]`), reset
routine, QSPI bus setup, and the panel-revision auto-detect logic
that reads chip register `0x04` to pick which init array to use.

#### `Arduino/examples/01_lvgl_example/Display_ST77916.h`

Pin definitions (`LCD_*`, backlight), SPI clock (`80 MHz`), backlight
PWM frequency (`20 kHz`, 10-bit resolution).

#### `Arduino/examples/01_lvgl_example/TCA9554PWR.h`

TCA9554 expander I²C address (`0x20`), EXIO pin numbering, register
layout (input/output/polarity/config registers).

#### `Arduino/examples/01_lvgl_example/Touch_CST816.h`

CST816 touch controller wiring + reset behaviour through the
expander (uses `EXIO_PIN1`).

#### `ESP-IDF/ESP32-S3-Touch-LCD-1.85C-Test/ESP32-S3-Touch-LCD-1.85C-Test/main/main.c`

The boot-time init order: `EXIO_Init` (TCA9554) → `SD_Init` →
`LCD_Init` (which does ST77916 reset + init then touch init) →
`Audio_Init`. Useful when ESPHome's component dependency order is
in doubt.

#### `hardware/`

Schematics + PCB. Reach for when a pin assignment, polarity, or
power rail is unclear.

### Cross-references in our code

Anywhere our YAML follows a non-obvious choice taken from this
reference, the comment cites the file:line — search for "Waveshare
reference" in `waveshare-1.85c.yaml`.
