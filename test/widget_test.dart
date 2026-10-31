import 'package:aquawatch/level.dart';
import 'package:aquawatch/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline screen never claims a level and calibration opens', (
    tester,
  ) async {
    await tester.pumpWidget(const AquaWatchApp(startUsb: false));
    expect(find.text('AquaWatch'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Waiting for sensor'), findsOneWidget);
    expect(find.text('Low Water'), findsNothing);
    expect(find.text('Full'), findsNothing);
    expect(find.text('LEVEL · 0–9'), findsOneWidget);
    expect(find.text('EVENT LOG · 0'), findsOneWidget);
    expect(find.text('Waiting for a live reading.'), findsOneWidget);
    await tester.tap(find.byTooltip('Sensor settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Empty · 50   Full · 550'), findsOneWidget);
    // Calibration needs a live reading.
    final setEmpty = find.widgetWithText(OutlinedButton, 'Set empty');
    expect(tester.widget<OutlinedButton>(setEmpty).onPressed, isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for sensor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('level alert banner warns on low water and dismisses', (
    tester,
  ) async {
    var dismissed = false;
    Widget banner(LevelBand band) => MaterialApp(
      home: Scaffold(
        body: LevelAlertBanner(band: band, onDismiss: () => dismissed = true),
      ),
    );
    await tester.pumpWidget(banner(LevelBand.low));
    expect(find.text('Low water · refill the tank'), findsOneWidget);
    await tester.pumpWidget(banner(LevelBand.full));
    expect(find.text('Water level back to normal'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss alert'));
    expect(dismissed, true);
  });
}
