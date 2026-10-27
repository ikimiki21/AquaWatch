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
    await tester.tap(find.byTooltip('Sensor settings'));
    await tester.pumpAndSettle();
    expect(find.text('Detection threshold · 400'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Apply settings'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for sensor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
