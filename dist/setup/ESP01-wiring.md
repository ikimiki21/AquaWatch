# ESP-01 connection for AquaWatch

The Uno firmware reads the sensor on A0 and controls LEDs on D10–D12.
The optional Wi-Fi variant uses `SoftwareSerial wifi(2, 3)` (Uno RX, Uno TX).
See [WIFI-SETUP.md](WIFI-SETUP.md) for the two sketches and hotspot setup.

Disconnect power before changing wiring. Verify the module's printed labels;
the positive supply pin should be VCC, not VSS.

| ESP-01 pin | Connection |
| --- | --- |
| VCC | Regulated 3.3 V supply capable of at least 500 mA |
| GND | Supply ground and Uno GND (all grounds common) |
| TX | Uno D2 (Uno receives here) |
| RX | Uno D3 through a suitable 5 V-to-3.3 V UART logic-level converter |
| EN / CH_PD | Pull up to the ESP's 3.3 V supply (for example through 10 kohm) |

Follow the exact ESP-01 board's normal-boot requirements for RST, GPIO0 and
GPIO2; do not ground GPIO0 during normal operation. Some adapter boards include
the required pull-ups, regulator and level conversion; check the adapter's
schematic rather than assuming these components are included.

The Uno's 3.3 V output is rated for only 50 mA, which is insufficient for a
reliable ESP8266 power supply. ESP8266 GPIO is not 5 V tolerant. Never connect
Uno D3 directly to a bare ESP-01 RX pin while driving D3 as a serial output.
Never apply 5 V directly to the ESP-01 VCC pin.

The provided ESP sketch replaces the ESP's existing firmware and uses 9600 baud
at runtime. Flash the ESP and enable the Uno Wi-Fi variant only after correcting
the power and logic wiring. No Wi-Fi-capable sketch has been uploaded yet.

References:

- [Arduino Uno R3 pinout: 3.3 V current limit](https://content.arduino.cc/assets/Pinout-UNOrev3_latest.pdf)
- [Espressif ESP8266 FAQ: power supply, logic levels and chip enable](https://www.espressif.com/en/products/socs/esp8266ex/resources/)
