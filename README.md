# AquaWatch

A small Flutter app for an Arduino Uno R3 and a three-pin **analog** moisture/water sensor. Connect using the ESP-01's own **AquaWatch Wi-Fi hotspot**, Android USB OTG, or desktop Chrome/Edge USB serial. No router, account, database, Bluetooth, or internet service is needed. The app displays real ADC readings, water status, and connection status. Arduino samples every 500 ms and controls three status LEDs; the Wi-Fi app polls every second.

**Wi-Fi setup:** read [docs/WIFI-SETUP.md](docs/WIFI-SETUP.md). The ESP-01 creates network **AquaWatch**, password **AquaWatch123**, address **192.168.4.1**. Join it in the phone's Wi-Fi settings, choose to stay connected without internet, and tap **Connect via Wi-Fi** in the app. Both the Uno Wi-Fi variant and ESP-01 firmware must be installed first. The reported direct Uno 3.3 V supply and unshifted D3 connection need correction before those firmware uploads.

## Files

- `lib/main.dart`: Material 3 interface and calibration sheet.
- `lib/usb_controller.dart`: shared connection state for Wi-Fi, Android USB, and browser USB.
- `lib/wifi_link.dart`: local HTTP polling, validation, and confirmed calibration changes.
- `lib/sensor.dart`: serial decoding and water detection.
- `lib/browser_serial_web.dart` and `web/serial_bridge.js`: desktop Chrome/Edge serial connection.
- `docs/ESP01-wiring.md`: ESP-01 power, level conversion, and UART wiring.
- `docs/WIFI-SETUP.md`: offline hotspot setup and programming instructions for both boards.
- `arduino/AquaWatch/AquaWatch.ino`: complete Arduino IDE sketch, no extra libraries.
- `arduino/AquaWatchESP01/AquaWatchESP01.ino`: ESP-01 SoftAP and local HTTP server (custom firmware; replaces AT firmware).
- `android/`: complete Android runner with USB host support and device filters.
- `test/`: protocol, detection, and app checks.
- `third_party/usb_serial/`: bundled usb_serial 0.5.2 runtime with updated Gradle configuration; see its README and license. This avoids the upstream package's obsolete `jcenter()` calls, which Gradle 9 removed. The Dart/Java USB implementation is unchanged. The native driver downloads from JitPack at build time.

## Hardware and wiring

For mobile use you need the Uno R3, the sensor, jumper wires, an Android phone supporting **USB host / OTG**, an OTG adapter matching the phone, and a USB **data** cable matching the Uno (normally USB-A to USB-B). No Bluetooth module is needed. On this computer you can instead connect the Uno directly by USB and use desktop Chrome/Edge.

Disconnect power while wiring. Follow the printed pin labels, not the order of the pins.

| Sensor pin | Arduino Uno R3 |
| --- | --- |
| `+` | `5V` **only if the sensor is rated for 5V**; otherwise use its specified supply |
| `-` | `GND` |
| `S` | `A0` |

LED wiring: connect each LED's anode (long leg) to its pin through a **220–330 ohm series resistor**, and its cathode (short leg) to GND. Each LED needs its own resistor.

| LED | Uno pin | Meaning |
| --- | --- | --- |
| Red | D10 | Water detected |
| Yellow | D11 | Startup, or dry reading within 40 counts of the threshold |
| Green | D12 | Dry reading farther from the threshold |

Only one LED is on at a time. The LEDs operate even when the app is disconnected. Default threshold is 400, with higher values meaning wet. App calibration is sent to the board and remains until the Uno resets or receives new settings.

The sensor model is unspecified: the software assumes `S` is an analog voltage output. Check its rated voltage and output type first. A digital-only `S` provides only wet/dry levels, not a meaningful continuous moisture measurement. A0 must stay between GND and 5V. Keep the Uno, phone, cable, and the sensor's electronics dry; only expose the sensor's intended sensing area to water.

```text
Android phone -> USB OTG adapter -> USB data cable -> Uno USB port
                                                       |
                                                  +    -    S
                                                  |    |    |
                                                 5V   GND   A0
```

USB normally powers the board and sensor. If the phone cannot power the assembly reliably, use a suitable powered OTG hub. Enable OTG in phone settings if your model requires it.

## 1. Upload the Arduino code

1. Install Arduino IDE on your computer.
2. Open `arduino/AquaWatch/AquaWatch.ino`.
3. Connect the Uno to the computer with its USB data cable.
4. Select **Arduino Uno** under Tools > Board and select its port.
5. Click **Upload**.
6. Optional: open Serial Monitor at **9600 baud**. You should see lines like `AQ,1,123`, twice per second. Check that the raw number changes between dry and wet conditions.
7. Close Serial Monitor and disconnect the Uno from the computer.

## 2. Build and install the app

Use Flutter 3.44 / Dart 3.12 or compatible newer releases and an Android SDK with the platform/build tools required by Flutter. Android Studio's SDK Manager provides these; run `flutter doctor` to check setup. Use the JDK recommended by your installed Flutter/Android Gradle Plugin (JDK 17 or newer).

From this project directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Install `dist/AquaWatch-1.0.0.apk` on the phone. The `dist/AquaWatch-1.0.0-Android.zip` package also contains setup instructions and both Arduino IDE sketches. Transfer the APK to the phone, open it, and allow installation from that source when Android asks. Alternatively, connect the phone to your computer with USB debugging enabled and use `flutter run --release`, then disconnect it before attaching the Uno.

The release APK is signed with this project's private release key in `.signing/`. Keep that folder safe: future updates must use the same key. Run `powershell -File tools/package_release.ps1` after building to verify the signature and recreate `dist/`. Android's `INTERNET` permission is required for sockets to the local ESP hotspot; no internet service is required. HTTP is permitted specifically for `192.168.4.1`. Package downloads and initial build setup need internet on the computer; the installed app works offline.

## 3. Connect and calibrate

### Desktop Chrome/Edge on this computer

Run `flutter run -d chrome -t lib/preview.dart --web-port 7357` and open `http://localhost:7357`. Despite its historical filename, `preview.dart` launches the live app. For Wi-Fi, join the hotspot from this computer and tap **Connect via Wi-Fi**; allow local-network access if prompted. For USB, select **USB**, close Arduino Serial Monitor, click **Connect Arduino**, choose **Arduino Uno (COM8)** in the browser's port chooser, and click Connect. There are no simulated readings. Disconnect before uploading another sketch. Web Serial requires desktop Chrome/Edge on localhost or HTTPS.

### Android phone over USB (Wi-Fi instructions are in docs/WIFI-SETUP.md)

1. Connect the Uno to the phone through the OTG adapter and data cable.
2. Open AquaWatch, select **USB**, tap **Connect Arduino**, and allow Android's USB permission prompt.
3. Wait a few seconds: opening the serial port may reset the Uno.
4. Record the raw reading with the sensing area dry, then with it wet.
5. Open the settings icon. Set the threshold roughly halfway between those readings. Leave **Higher value means wet** enabled if the wet reading is higher; disable it if the wet reading is lower. Tap **Apply settings**.

Example: dry = 80, wet = 650 -> threshold around 365, higher means wet enabled. Dry = 850, wet = 300 -> threshold around 575, higher means wet disabled. The default 400 is a starting point, not a universal calibration. The slider allows 20–1003 so both directions have room for the stability margin.

**Green / No Water Detected** means normal. **Red / Water Detected** means warning. Disconnected, starting, and missing-data states are neutral and never claim the sensor is dry. Settings are kept in memory. USB starts with 400 / higher means wet when the app restarts; Wi-Fi follows the settings reported by the Uno, which resets them when it restarts. The displayed value is a **0–1023 ADC reading**, not a calibrated moisture percentage.

## Communication and behavior

- Serial: **9600 baud, 8 data bits, no parity, 1 stop bit, no flow control**.
- Arduino frame: `AQ,1,<value>\r\n`, where value is an integer from 0 to 1023. `1` is the protocol version.
- App-to-board settings: `CFG,<threshold>,<direction>\n`, where direction is 1 for higher-is-wet or 0 for lower-is-wet. The app sends settings after the first valid reading (after Uno startup) and when Apply settings is pressed. Arduino uses the same threshold/hysteresis for the red LED as the app does for water detection.
- The app buffers partial USB packets, handles multiple frames in one packet, and ignores invalid frames and excessively long lines.
- Higher-is-wet: warning begins at `value >= threshold`; it clears below `threshold - 20`.
- Lower-is-wet: warning begins at `value <= threshold`; it clears above `threshold + 20`.
- On the first reading, detection uses the threshold directly. The 20-count hysteresis reduces flicker afterward.
- If valid data stops for over 4 seconds, the reading is cleared and status becomes unavailable. The USB port can still be connected; USB connection and sensor data availability are separate states. Valid readings restore the display automatically.
- Disconnect clears the reading. USB attachment/removal triggers a scan. After unplugging and replugging the selected board, a single attached device reconnects automatically. Permission denial requires a manual retry.
- This is a foreground monitor. Android can suspend an app in the background; keep it open for live monitoring. It is not a background alarm service.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No USB device found | Phone supports OTG, OTG is enabled, adapter is a host adapter, cable supports data, Uno power LED is on. |
| Permission denied | Tap Connect and allow USB access. Replug the cable if necessary. |
| Connected but no reading | Correct sketch uploaded, Serial Monitor shows `AQ,1,<number>` at 9600, wait for Uno reset, then disconnect/reconnect. |
| Water status reversed | Change Higher value means wet in settings. |
| Always dry or always wet | Check `S -> A0`, common GND, module voltage, analog output type, and recalibrate the threshold. |
| Values jump with nothing attached | A floating A0 does not detect a missing sensor. USB connection does not prove the sensor is wired correctly. |
| Uno clone fails | The USB plugin supports CDC, CH340/CH341, FTDI and CP210x families, but the particular board/phone must be checked. Auto-launch filters cover common IDs; manual scanning also lists other devices. |
| Flutter reports missing Android SDK | Install/configure the SDK with Android Studio; run `flutter doctor --android-licenses` and `flutter doctor`. |

## References

- [Arduino analog input and the 0–1023 range](https://docs.arduino.cc/tutorials/uno-rev3/AnalogReadSerial/)
- [Flutter USB serial plugin API](https://pub.dev/documentation/usb_serial/0.5.2/)
- [Android USB host overview](https://developer.android.com/develop/connectivity/usb/host)
- [Chrome Web Serial and its required port chooser](https://developer.chrome.com/docs/capabilities/serial)

Physical verification requires your phone, OTG adapter, Uno, and exact sensor. Software checks alone cannot establish sensor polarity, calibration, phone power capacity, or board driver compatibility.

## Verification in this workspace

The sketch was compiled for `arduino:avr:uno` using the installed Arduino AVR core 1.8.8 and uploaded successfully to the Uno identified on COM8. Eight serial samples were read; valid frames reported `AQ,1,0`. This verifies the board's firmware and USB stream. Wet/dry calibration and the physical illumination of each LED still need observation with the user's sensor and wiring.

`flutter analyze` and eleven Flutter tests cover fragmented/invalid serial frames, both wet/dry directions and hysteresis, the interface and settings, simulated USB connection handling, and local Wi-Fi HTTP validation, settings acknowledgment, timeout/recovery, and mode switching. Two Node tests (`node --test tools/test_serial_bridge.cjs`) cover browser streaming, settings writes, cleanup, and unplug notification. Mocked tests do not establish physical LED operation. The updated Flutter web app compiled with local rendering resources (`--no-web-resources-cdn`). The Uno Wi-Fi variant also compiles; Wi-Fi firmware has not been uploaded because the ESP power and RX logic wiring needs correction.

Both the Uno Wi-Fi variant and the ESP-01 hotspot sketch compiled successfully. See `docs/WIFI-SETUP.md` for flashing instructions and remaining hardware verification. Neither Wi-Fi sketch has been uploaded. The Android SDK is installed, and the signed release APK built successfully. Physical phone installation and Wi-Fi operation still require verification with the user's hardware.
