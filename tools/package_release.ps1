param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceApk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (!(Test-Path -LiteralPath $sourceApk)) { throw 'Build the release APK first.' }
$androidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$signatureTool = Join-Path $androidSdk 'build-tools\36.0.0\apksigner.bat'
if (!(Test-Path -LiteralPath $signatureTool)) { throw 'Android Build Tools 36.0.0 is required to verify the APK.' }
& $signatureTool verify --verbose --print-certs $sourceApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$releaseDirectory = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
$apkName = "AquaWatch-$Version.apk"
$targetApk = Join-Path $releaseDirectory $apkName
Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force

$installText = @'
AquaWatch for Android

INSTALL
1. Copy the APK to your Android phone (Android 7.0 or newer).
2. Open it on the phone. Allow installation from that file source if Android asks.
3. Open AquaWatch after installation.

CONNECT
Connect the Uno to the phone with a USB OTG adapter and a USB data cable,
tap Connect Arduino, and allow Android's USB permission prompt.
The app reads the serial port only. There is no Wi-Fi, Bluetooth or network
connection of any kind, and no internet service is used at any point.

WIRING
Sensor: S -> A0, minus -> GND, plus -> D7 (switched on only while sampling).
LEDs: red D10 (low water), yellow D11 (halfway), green D12 (full).
Each LED needs its own 220-330 ohm series resistor.
Buzzer: + -> D9, - -> GND. It beeps once a second while the tank runs low.

CALIBRATE
In the app's settings, record the reading with the probe dry (Set empty), then
with it fully immersed (Set full). Everything between is scaled to a level of
0 to 9. Levels 0-2 are low water, 3-6 halfway, 7-9 full. The calibration is
sent to the Uno so the LEDs match the screen; the Uno forgets it on reset.

PACKAGE CONTENTS
- Signed release APK (production mode; no Flutter development tools needed).
- firmware/AquaWatch/AquaWatch.ino: the Arduino IDE sketch, no extra libraries.
- SHA256SUMS.txt: APK integrity checksum.

The APK signature and package are verified during packaging.
The private signing key remains in the project's .signing folder and is not
included here. Keep that folder safe to sign compatible future app updates.
'@
[System.IO.File]::WriteAllText((Join-Path $releaseDirectory 'INSTALL.txt'), $installText, [System.Text.UTF8Encoding]::new($false))

$sketchDestination = Join-Path $releaseDirectory 'firmware\AquaWatch'
New-Item -ItemType Directory -Path $sketchDestination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'arduino\AquaWatch\AquaWatch.ino') -Destination $sketchDestination -Force
$checksum = (Get-FileHash -LiteralPath $targetApk -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText((Join-Path $releaseDirectory 'SHA256SUMS.txt'), "$checksum  $apkName`n", [System.Text.UTF8Encoding]::new($false))
$zipPath = Join-Path $releaseDirectory "AquaWatch-$Version-Android.zip"
Compress-Archive -LiteralPath $targetApk,(Join-Path $releaseDirectory 'INSTALL.txt'),(Join-Path $releaseDirectory 'firmware'),(Join-Path $releaseDirectory 'SHA256SUMS.txt') -DestinationPath $zipPath -Force
Get-Item -LiteralPath $targetApk,$zipPath | Select-Object Name,Length,FullName
