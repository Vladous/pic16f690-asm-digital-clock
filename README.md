# pic16f690-asm-digital-clock
Digital clock in PIC16F690 assembly with HD44780 LCD (4-bit mode), button time setup and HH:MM:SS display.

## Project layout

- `/src/main.asm` – PIC16F690 firmware in MPASM/gpasm syntax
- `/Makefile` – build helper (`make` -> `build/main.hex`)

## Hardware mapping

### LCD (HD44780, 4-bit mode)
- `RC0` -> `RS`
- `RC1` -> `E`
- `RC4` -> `D4`
- `RC5` -> `D5`
- `RC6` -> `D6`
- `RC7` -> `D7`

### Buttons (active low, weak pull-ups enabled)
- `RA0` -> `MODE` (enter/exit time setup)
- `RA1` -> `NEXT` (select field: HH -> MM -> SS)
- `RA2` -> `UP` (increment selected field)

## Behavior

- Default start time: `12:00:00`
- Normal mode: displays `HH:MM:SS` and increments once per second
- Setup mode:
  - `MODE` exits setup
  - `NEXT` selects hours/minutes/seconds
  - `UP` increments currently selected field

## Build

Install `gputils` (for `gpasm`) and run:

```bash
make
```

Generated output:
- `build/main.hex`
