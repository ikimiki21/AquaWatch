# AquaWatch

A small Flutter app for an Arduino Uno R3 and a three-pin **analog** water level sensor. The Uno estimates the water level on a **0–9** scale, shows it on three LEDs, and beeps while the tank runs low. The app shows the same level live over the USB cable.

**The only connection is USB.** No Wi-Fi, Bluetooth, router, account, database, cloud service, or internet connection is used at any point. Two ways to connect:

- **Android phone:** a USB OTG adapter and a USB data cable to the Uno.
- **This computer:** desktop Chrome or Edge, using Web Serial over the same cable you upload with.

## Files

- `lib/main.dart`: Material 3 interface and the calibration sheet.
- `lib/level.dart`: the 0–9 level model, bands, and hysteresis.
- `lib/usb_controller.dart`: connection state for Android USB and browser USB.
- `lib/sensor.dart`: serial frame decoding.
- `lib/browser_serial_web.dart` and `web/serial_bridge.js`: desktop Chrome/Edge serial connection.
- `arduino/AquaWatch/AquaWatch.ino`: the complete Arduino IDE sketch, no extra libraries.
- `android/`: Android runner with USB host support and device filters.
- `test/`: level model, serial protocol, event log, and interface checks.
- `docs/paper-revisions.md`: the written report's corrections, for whoever revises it.
- `third_party/usb_serial/`: bundled usb_serial 0.5.2 runtime with updated Gradle configuration; see its README and license. This avoids the upstream package's obsolete `jcenter()` calls, which Gradle 9 removed. The Dart/Java USB implementation is unchanged. The native driver downloads from JitPack at build time.

## Hardware and wiring

You need the Uno R3, the sensor, three LEDs, three 220–330 ohm resistors, a buzzer, a breadboard, jumper wires, and the Uno's USB data cable. For the phone, add a USB **host / OTG** adapter matching your phone.

Disconnect power while wiring. Follow the printed pin labels, not the physical order of the pins.

| Sensor pin | Arduino Uno R3 |
| --- | --- |
| `+` | `D7` **only if the sensor is rated for 5 V**; otherwise use its specified supply. D7 is switched on only while a sample is taken, so the probe is not under constant DC, which corrodes it. A pin supplies at most 20 mA: a module needing more must take its own supply and share GND. |
| `-` | `GND` |
| `S` | `A0` |

LED wiring: each LED's anode (long leg) goes to its pin through its **own** 220–330 ohm series resistor; the cathode (short leg) goes to GND.

| LED | Uno pin | Meaning | Level |
| --- | --- | --- | --- |
| Red | `D10` | Low water — refill the tank | 0–2 |
| Yellow | `D11` | Halfway (also lit at startup) | 3–6 |
| Green | `D12` | Full | 7–9 |

Buzzer: `+` to `D9`, `-` to `GND`. It sounds a short beep once a second while the level is low, including at level 0 — an empty tank is the most urgent case, not a quiet one. The sketch assumes a **passive** buzzer and drives it with `tone()`; set `AQUAWATCH_PASSIVE_BUZZER` to 0 for an active buzzer, which is switched on and off instead.

Exactly one LED is lit at a time. The LEDs and buzzer work whether or not the app is connected — the Uno decides on its own.

The sensor model is unspecified: the software assumes `S` is an analog voltage output. Check its rated voltage and output type first. A digital-only `S` gives only a wet/dry level, not a continuous measurement, so the 0–9 scale would collapse to its ends. A0 must stay between GND and 5 V. Keep the Uno, cable, and the sensor's electronics dry; only the sensor's intended sensing area goes in the water.

```text
This computer  -> USB data cable --------+
Android phone  -> OTG adapter -> cable --+-> Uno USB port
                                              |
                                         +    -    S
                                         |    |    |
                                        D7   GND   A0
```

USB powers the board and the sensor. There is no battery. If the phone cannot power the assembly reliably, use a powered OTG hub. Enable OTG in phone settings if your model requires it.

## 1. Upload the Arduino code

1. Install Arduino IDE on your computer.
2. Open `arduino/AquaWatch/AquaWatch.ino`.
3. Connect the Uno to the computer with its USB data cable.
4. Select **Arduino Uno** under Tools > Board and select its port.
5. Click **Upload**.
6. Optional: open Serial Monitor at **9600 baud**. You should see lines like `AQ,1,123`, twice per second. Check that the number changes between dry and immersed.
7. Close Serial Monitor before connecting the app — only one program can hold the port.

## 2. Build and install the app

Use Flutter 3.44 / Dart 3.12 or compatible newer releases. For the Android build you also need an Android SDK with the platform and build tools Flutter requires; Android Studio's SDK Manager provides these. Run `flutter doctor` to check. Use the JDK recommended by your Flutter/Android Gradle Plugin (JDK 17 or newer).

From this project directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Install `dist/AquaWatch-1.0.0.apk` on the phone. The `dist/AquaWatch-1.0.0-Android.zip` package also contains the setup notes and the Arduino sketch. Transfer the APK to the phone, open it, and allow installation from that source when Android asks. Alternatively connect the phone with USB debugging enabled and run `flutter run --release`, then disconnect it before attaching the Uno.

The release APK is signed with this project's private release key in `.signing/`. Keep that folder safe: future updates must use the same key. Run `powershell -File tools/package_release.ps1` after building to verify the signature and recreate `dist/`. The app requests no network permission; package downloads and the initial build need internet on the computer, but the installed app has no network access at all.

## 3. Connect and calibrate

### Desktop Chrome/Edge on this computer

Run `flutter run -d chrome -t lib/preview.dart --web-port 7357` and open `http://localhost:7357`. Despite its historical filename, `preview.dart` launches the live app. Close Arduino Serial Monitor, click **Connect Arduino**, choose your Uno in the browser's port chooser, and click Connect. There are no simulated readings. Disconnect before uploading another sketch. Web Serial requires desktop Chrome or Edge on localhost or HTTPS.

### Android phone over USB

1. Connect the Uno to the phone through the OTG adapter and data cable.
2. Open AquaWatch, tap **Connect Arduino**, and allow Android's USB permission prompt.
3. Wait a few seconds: opening the serial port may reset the Uno.

### Calibration

Calibration is two measurements, not a guess:

1. With the sensing area **dry**, open the settings icon and tap **Set empty**.
2. Fully immerse the sensing area and tap **Set full**.

Everything in between is scaled to a level of 0–9. **Reset** restores the 50 / 550 defaults, which are a starting point, not a universal calibration. The direction is measured, not declared: a sensor whose reading *falls* as water rises calibrates the same way, because the span carries the sign. Empty and full must differ by at least 10 counts or the app reports no level and asks you to recalibrate.

The app sends the calibration to the Uno so the LEDs use the same scale as the screen. The Uno keeps it in RAM and returns to 50 / 550 when it resets — including when the app opens the serial port, which is why the app resends it after the first reading.

**Red / Low Water** is the warning. **Yellow / Halfway** and **Green / Full** are normal. Disconnected, starting, and missing-data states are neutral grey and never claim a level.

## Communication and behavior

- Serial: **9600 baud, 8 data bits, no parity, 1 stop bit, no flow control**.
- Board to app: `AQ,1,<value>\r\n`, where value is the raw ADC reading, 0 to 1023. `1` is the protocol version.
- App to board: `CAL,<empty>,<full>\n`. Both must be 0–1023 and differ by at least 10, or the Uno ignores the line. The app sends it after the first valid reading and whenever calibration changes.
- The Uno averages eight ADC samples every 500 ms, powering the probe only for the sample.
- Level: `(value - empty) / (full - empty)`, clamped to 0–9. Low below 30% of the span, full at 70% and above.
- A band holds until the reading clears its boundary by 2% of the span, so a level resting on an edge cannot flicker the LEDs or the screen. The Uno applies the same margin.
- The app buffers partial USB packets, handles several frames in one packet, and ignores invalid frames and over-long lines.
- If valid data stops for over 4 seconds the reading is cleared and the status becomes unavailable. The port can still be open: connection and data availability are separate states. A valid reading restores the display automatically.
- Disconnect clears the reading. USB attach/remove triggers a scan, and a single attached board reconnects automatically after a replug. Permission denial needs a manual retry.
- This is a foreground monitor. Android can suspend a background app; keep it open for live monitoring. It is not a background alarm service.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No USB device found | Phone supports OTG, OTG is enabled, the adapter is a host adapter, the cable carries data, the Uno power LED is on. |
| Permission denied | Tap Connect and allow USB access. Replug the cable if necessary. |
| Browser port chooser is empty | Close Arduino Serial Monitor and any other program holding the port, then click Connect again. |
| Connected but no reading | Correct sketch uploaded, Serial Monitor shows `AQ,1,<number>` at 9600, wait for the Uno reset, then disconnect and reconnect. |
| Level never leaves 0 or 9 | Empty and full are too close, or the sensor's `S` is digital rather than analog. Recalibrate from real dry and immersed readings. |
| LEDs disagree with the screen | The Uno was reset after calibration. Reconnect, or open settings and tap Set empty / Set full again. |
| Level drifts with nothing attached | A floating A0 reads noise. A USB connection does not prove the sensor is wired correctly. |
| Uno clone fails | The USB plugin supports CDC, CH340/CH341, FTDI and CP210x families, but your particular board and phone must be checked. Auto-launch filters cover common IDs; manual scanning also lists other devices. |
| Flutter reports a missing Android SDK | Install and configure the SDK with Android Studio, then run `flutter doctor --android-licenses` and `flutter doctor`. |

## References

- [Arduino analog input and the 0–1023 range](https://docs.arduino.cc/tutorials/uno-rev3/AnalogReadSerial/)
- [Flutter USB serial plugin API](https://pub.dev/documentation/usb_serial/0.5.2/)
- [Android USB host overview](https://developer.android.com/develop/connectivity/usb/host)
- [Chrome Web Serial and its required port chooser](https://developer.chrome.com/docs/capabilities/serial)

## Verification in this workspace

- The sketch compiles for `arduino:avr:uno` with Arduino AVR core 1.8.8: 5718 bytes of program storage, 256 bytes of RAM.
- `flutter analyze` reports no issues. Thirteen Flutter tests pass, covering the 0–9 level model in both sensor directions, band hysteresis, the documented depth trials, fragmented and invalid serial frames, the `CAL` handshake, timeout and recovery, USB permission denial and detach, the event log, and the interface.
- Two Node tests (`node --test tools/test_serial_bridge.cjs`) cover browser streaming, settings writes, cleanup, and unplug notification.
- The signed release APK built successfully with the installed Android SDK.

Not verified, and not verifiable from software alone: the physical illumination of each LED, the buzzer's sound, this sensor's real dry and immersed readings, its polarity, whether its `S` output is analog, and installation on the phone. Those need the assembled hardware. An earlier upload to this Uno produced `AQ,1,0` for eight samples, which confirms the firmware and the USB stream but says nothing about the sensor, as `A0` was unconnected.
