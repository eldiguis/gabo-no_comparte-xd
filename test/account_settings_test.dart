import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('account tab exposes account and accessibility settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ShopShell(customerName: 'Gabriela')),
    );
    await tester.pump();
    await tester.tap(find.text('Cuenta'));
    await tester.pump();

    expect(find.text('Mi cuenta'), findsNothing);
    expect(find.text('Gabriela'), findsOneWidget);
    expect(find.text('Accesibilidad'), findsOneWidget);
    expect(find.text('Texto grande'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);

    final textSizeSwitch = find.ancestor(
      of: find.text('Texto grande'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(textSizeSwitch).value, isFalse);
    await tester.tap(textSizeSwitch);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(textSizeSwitch).value, isTrue);
  });
}
