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

WI-FI
The ESP-01 and Uno need the provided Wi-Fi firmware and correct wiring first.
Join Wi-Fi network: AquaWatch
Wi-Fi password: AquaWatch123
Choose Stay connected / Use this network when Android says No internet.
In AquaWatch, select Wi-Fi and tap Connect via Wi-Fi.
Readings refresh every second. Internet service and a router are not required.

USB
Select USB in the app, connect the Uno through a USB OTG adapter and data cable,
tap Connect Arduino, and allow Android's USB permission prompt.

HARDWARE SETUP STILL REQUIRED FOR WI-FI
The reported ESP-01 wiring used the Uno 3.3 V pin and no RX level converter.
If ESP-01 VCC was moved directly to 5 V, disconnect it now: the bare ESP-01
must receive 3.3 V, never 5 V. A 5 V input is safe only through a regulator
or adapter that supplies 3.3 V to ESP-01 VCC.
Correct this before enabling the Uno's Wi-Fi firmware: use an appropriate
regulated 3.3 V supply rated for at least 500 mA, UART level conversion from
Uno D3 to ESP RX, and common grounds. See setup/WIFI-SETUP.md.
The Wi-Fi firmware has not been uploaded to that uncorrected wiring.

Sensor S -> A0, minus -> GND, plus -> 5 V only for a 5 V-compatible sensor.
LEDs: red D10, yellow D11, green D12; each needs a series resistor.
Calibrate the threshold from actual dry/wet readings in the app's settings.

PACKAGE CONTENTS
- Signed release APK (production mode; no Flutter development tools needed).
- setup/: wiring and firmware flashing instructions.
- firmware/: Uno and ESP-01 Arduino IDE source sketches.
- SHA256SUMS.txt: APK integrity checksum.

The APK signature and package are verified during packaging. Physical Wi-Fi
operation still requires the corrected wiring and firmware uploads.
The private signing key remains in the project's .signing folder and is not
included here. Keep that folder safe to sign compatible future app updates.
'@
[System.IO.File]::WriteAllText((Join-Path $releaseDirectory 'INSTALL.txt'), $installText, [System.Text.UTF8Encoding]::new($false))

$setupDirectory = Join-Path $releaseDirectory 'setup'
New-Item -ItemType Directory -Path $setupDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\WIFI-SETUP.md'),(Join-Path $projectRoot 'docs\ESP01-wiring.md') -Destination $setupDirectory -Force
foreach ($sketchName in @('AquaWatch', 'AquaWatchESP01')) {
    $sketchDestination = Join-Path $releaseDirectory "firmware\$sketchName"
    New-Item -ItemType Directory -Path $sketchDestination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot "arduino\$sketchName\$sketchName.ino") -Destination $sketchDestination -Force
}
$checksum = (Get-FileHash -LiteralPath $targetApk -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText((Join-Path $releaseDirectory 'SHA256SUMS.txt'), "$checksum  $apkName`n", [System.Text.UTF8Encoding]::new($false))
$zipPath = Join-Path $releaseDirectory "AquaWatch-$Version-Android.zip"
Compress-Archive -LiteralPath $targetApk,(Join-Path $releaseDirectory 'INSTALL.txt'),$setupDirectory,(Join-Path $releaseDirectory 'firmware'),(Join-Path $releaseDirectory 'SHA256SUMS.txt') -DestinationPath $zipPath -Force
Get-Item -LiteralPath $targetApk,$zipPath | Select-Object Name,Length,FullName
