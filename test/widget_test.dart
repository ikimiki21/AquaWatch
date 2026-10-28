import 'package:aquawatch/level.dart';
import 'package:aquawatch/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline screen never claims dry and calibration opens', (
    tester,
  ) async {
    await tester.pumpWidget(const AquaWatchApp(startUsb: false));
    expect(find.text('AquaWatch'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Waiting for sensor'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Password: AquaWatch123'), findsOneWidget);
    expect(find.text('No Water Detected'), findsNothing);
    expect(find.text('ESTIMATED LEVEL'), findsOneWidget);
    expect(find.text('EVENT LOG · 0'), findsOneWidget);
    expect(
      find.text('Calibrate empty and full in Sensor settings.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Sensor settings'));
    await tester.pumpAndSettle();
    expect(find.text('Detection threshold · 400'), findsOneWidget);
    // Calibration needs a live reading.
    final setEmpty = find.widgetWithText(OutlinedButton, 'Set empty');
    expect(tester.widget<OutlinedButton>(setEmpty).onPressed, isNull);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Apply settings'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for sensor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('level alert banner shows low/high and dismisses', (
    tester,
  ) async {
    var dismissed = false;
    Widget banner(LevelBand band) => MaterialApp(
      home: Scaffold(
        body: LevelAlertBanner(band: band, onDismiss: () => dismissed = true),
      ),
    );
    await tester.pumpWidget(banner(LevelBand.low));
    expect(find.text('Low water level · below 20%'), findsOneWidget);
    await tester.pumpWidget(banner(LevelBand.high));
    expect(find.text('High water level · 90% or above'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss alert'));
    expect(dismissed, true);
  });
}
