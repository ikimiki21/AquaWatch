# AquaWatch: its own Wi-Fi network, no internet

The ESP-01 runs in **SoftAP** mode. It creates this local network:

| Setting | Value |
| --- | --- |
| Wi-Fi name | `AquaWatch` |
| Wi-Fi password | `AquaWatch123` |
| Device address | `192.168.4.1` |
| Reading endpoint | `http://192.168.4.1/api/reading` |

No router, mobile data, internet connection, account, or database is required.
The phone joins the device's network using Android Wi-Fi settings, then the
installed Flutter app connects to the local device. Installing/building the app
and installing board packages on the computer require downloads beforehand.

## Correct the power and logic wiring first

The reported wiring powers the ESP directly from Uno 3.3 V and connects its RX
directly to D3. This must be corrected before enabling ESP communication.
Use the connections in [ESP01-wiring.md](ESP01-wiring.md): a regulated 3.3 V
supply capable of at least 500 mA, a suitable UART logic-level converter on
Uno D3 -> ESP RX, common ground, and proper enable/boot pull-ups.

Disconnect power while wiring. Do not power the bare ESP-01 from 5 V.
An ESP-01 adapter can provide these functions, but verify it actually includes
both the power regulator and UART level conversion; some adapters include only
a regulator. Use a 3.3 V UART programmer or an ESP-01 programming adapter for
the one-time ESP firmware upload. A programmer's 3.3 V label does not guarantee
its supply can deliver 500 mA; use the appropriate external regulator as needed.

## Two devices, two sketches

This implementation uses a custom ESP8266 Arduino sketch. It replaces any
existing AT firmware on the ESP-01, so no particular AT firmware version or
AT-command baud rate is required. Runtime Uno <-> ESP UART is 9600 baud.

### 1. Program the ESP-01

1. Install Arduino IDE. In Preferences, add this board package URL:
   `https://arduino.esp8266.com/stable/package_esp8266com_index.json`.
2. Use Boards Manager to install **esp8266 by ESP8266 Community**.
3. Disconnect the ESP from Uno D2/D3 while programming it.
4. Connect it to a suitable 3.3 V UART programmer: TX -> ESP RX, RX -> ESP TX,
   common GND, correct supply, EN high. Ensure the programmer's TX is 3.3 V logic.
5. Hold **GPIO0 low during reset/power-on** to enter upload mode. Keep GPIO2 high.
   Use the module's adapter instructions for its reset/program buttons or jumpers.
6. Open `arduino/AquaWatchESP01/AquaWatchESP01.ino`.
7. Select **Generic ESP8266 Module**, flash mode **DOUT**, upload speed **115200**,
   and the **actual flash size of your module** (commonly 1 MB; older units can be
   512 KB). Select the programmer's serial port, not automatically the Uno's COM8.
8. Upload, release GPIO0 high for normal boot, and reset the ESP.
9. Reconnect runtime wiring: ESP TX -> Uno D2; Uno D3 -> level converter -> ESP RX.

The hotspot may appear before Uno firmware is ready. The endpoint returns HTTP
503 until it receives fresh Uno sensor data; the app does not report a dry sensor
when those readings are missing.

### 2. Program the Uno

1. After the wiring is corrected, open `arduino/AquaWatch/AquaWatch.ino`.
2. Change `#define AQUAWATCH_ENABLE_WIFI 0` to `#define AQUAWATCH_ENABLE_WIFI 1`.
3. Select **Arduino Uno**, choose the Uno's port (observed as COM8), and upload.

The repository defaults to Wi-Fi **disabled** on the Uno so a routine upload
does not drive 5 V UART into the currently reported unprotected ESP RX wiring.
Sensor A0 and LEDs D10/D11/D12 remain the same. USB monitoring continues to work
when Wi-Fi is enabled. The Uno computes water detection and drives the LEDs;
the ESP serves those actual values and forwards calibration commands.

CLI compile commands (compilation does not upload):

```powershell
arduino-cli compile --fqbn arduino:avr:uno --build-property compiler.cpp.extra_flags=-DAQUAWATCH_ENABLE_WIFI=1 --output-dir build/arduino-wifi arduino/AquaWatch
arduino-cli compile --fqbn esp8266:esp8266:generic --output-dir build/esp01 arduino/AquaWatchESP01
```

## Connect the phone

1. Power the wired assembly using the appropriate supplies.
2. Open Android Wi-Fi settings and join **AquaWatch**, password **AquaWatch123**.
3. If Android says **No internet**, choose **Stay connected / Use this network**.
   Disable automatic switching to another Wi-Fi network if the phone leaves it.
   If the phone keeps routing app traffic over mobile data, temporarily turn
   mobile data off while using this offline hotspot.
4. Open the installed AquaWatch app, select **Wi-Fi**, and tap **Connect via Wi-Fi**.
5. Readings refresh every second. After connection loss, the app clears the old
   reading and retries automatically. The sensor/LEDs continue operating on Uno.
6. Test dry and wet readings and calibrate in settings. The Wi-Fi app waits for
   matching Uno telemetry before accepting threshold/polarity changes.

The Android manifest has `INTERNET` permission because Android uses that name for
local network sockets too. It does not mean internet service is needed. HTTP is
permitted specifically for `192.168.4.1` by the network security configuration.

The ESP-01 does not serve the complete Flutter app. Install the Android APK on
the phone beforehand. The local HTTP endpoint serves sensor data to that app.
The phone and board remain connected locally when internet service is absent.

## Desktop browser testing

Load the Flutter app at `http://localhost:7357` on the computer, join the same
**AquaWatch** hotspot from that computer, and use the Wi-Fi connection button.
Allow local-network access if the browser requests it. A browser tab on a different
network cannot reach `192.168.4.1`. Browser policies can restrict local HTTP access;
the Android app is the primary mobile target. USB remains available in desktop
Chrome/Edge by selecting **USB** and using its serial port chooser.

`flutter build web -t lib/preview.dart --no-web-resources-cdn` bundles the web
rendering resources for local hosting without a CDN. Serve the build directory
over localhost; opening index.html directly as a file is not supported.

## Data and freshness

- Uno -> ESP UART: `AQ,2,<value>,<threshold>,<higherMeansWet>,<waterDetected>\r\n`.
- ESP -> Uno UART: `CFG,<threshold>,<direction>\r\n`.
- `GET /api/reading` returns value (0–1023), threshold, polarity, actual detection
  state, device/version identity, and sample age. Missing Uno samples older than
  3 seconds produce HTTP 503.
- `POST /api/config`, form fields `threshold=400&higherMeansWet=1`, returns HTTP
  202 while the Uno command is pending. The app then checks actual reported
  settings. Invalid settings return HTTP 400.
- Neither device persists calibration in flash; it resets when Uno restarts.
- Change the hotspot password in the ESP sketch and update the app's displayed
  instructions together if customizing it.

## Verification limits

Both the Uno Wi-Fi variant (Arduino AVR core 1.8.8) and the ESP-01 sketch
(ESP8266 Arduino core 3.1.2, Generic ESP8266 Module) compile successfully.
The ESP firmware binary uses about 308 KB of flash. Flutter tests use mocked local HTTP responses
to check readings, stale data, settings acknowledgment, retries and disconnect.
Wi-Fi firmware has not been uploaded because the reported ESP power/logic wiring
needs correction. Physical hotspot creation and the phone-to-device flow require
that corrected wiring and an ESP programmer. The Android release APK built
successfully; installation and live Wi-Fi operation on a phone are not yet
verified with the user's hardware.

References:

- [ESP8266 SoftAP API](https://arduino-esp8266.readthedocs.io/en/latest/esp8266wifi/soft-access-point-class.html)
- [ESP8266 upload troubleshooting](https://arduino-esp8266.readthedocs.io/en/latest/faq/a01-upload-failed.html)
- [Android local HTTP network policy](https://developer.android.com/privacy-and-security/security-config)
