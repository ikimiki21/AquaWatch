# Bundled usb_serial 0.5.2

Source: https://pub.dev/packages/usb_serial/versions/0.5.2
Upstream: https://github.com/altera2015/usbserial
License: BSD-3-Clause (see LICENSE).

The Dart library and Android Java sources are unchanged. The manifest's legacy
package attribute is removed (the Gradle namespace supplies it). Android build
configuration is replaced to use the application's Android Gradle Plugin,
modern Android DSL, Java 17, and compile SDK 36. The obsolete plugin-owned
AGP 4.1.0 buildscript, jcenter() calls, and late task mutation are removed.
Gradle 9 removed jcenter():
https://docs.gradle.org/current/userguide/upgrading_major_version_9.html

The root project supplies JitPack to resolve the unchanged native USB driver
dependency com.github.felHR85:UsbSerial:6.1.0. No changes to the global Pub cache
are necessary. This folder deliberately includes only Android runtime sources,
the Dart library, pubspec, and license.
