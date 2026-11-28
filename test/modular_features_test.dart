import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/catalog/models/garment.dart';
import 'package:flutter_application_1/features/onboarding/user_guide_dialogs.dart';

void main() {
  group('Garment Sizing and Categories', () {
    test('Calculates shoe sizes for footwear', () {
      const shoe = Garment(
        id: 'shoe_1',
        name: 'Zapatilla Urban White',
        category: 'Calzado',
        price: 'S/ 249',
        image: '',
        tag: 'Calzado',
      );

      expect(shoe.availableSizes, containsAll(['37', '38', '39', '40']));
      expect(shoe.availableSizes, isNot(contains('M')));
    });

    test('Accessories without apparel sizes expose colors instead of sizes', () {
      const bag = Garment(
        id: 'bag_1',
        name: 'Bolso Tote Minimal',
        category: 'Accesorios',
        price: 'S/ 129',
        image: '',
        tag: 'Accesorios',
        color: 'Negro / Café',
      );

      expect(bag.hasSizes, isFalse);
      expect(bag.availableSizes, isEmpty);
      expect(bag.hasColors, isTrue);
      expect(bag.availableColors, equals(['Negro', 'Café']));
    });

    test('Calculates clothing sizes for apparel', () {
      const jacket = Garment(
        id: 'jacket_1',
        name: 'Casaca Denim Vintage',
        category: 'Sacos',
        price: 'S/ 189',
        image: '',
        tag: 'Sacos',
      );

      expect(jacket.availableSizes, containsAll(['S', 'M', 'L', 'XL', 'XXL']));
    });
  });

  group('Onboarding Guides Widget Rendering', () {
    testWidgets('WelcomeTourDialog renders without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WelcomeTourDialog()),
        ),
      );
      await tester.pump();

      expect(find.text('BIENVENIDO'), findsOneWidget);
      expect(find.text('Moda a tu manera'), findsOneWidget);
      expect(find.text('SIGUIENTE'), findsOneWidget);
    });

    testWidgets('SwipeToMatchGuideDialog renders without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SwipeToMatchGuideDialog()),
        ),
      );
      await tester.pump();

      expect(find.text('SWIPE TO MATCH'), findsOneWidget);
      expect(find.text('Desliza para combinar'), findsOneWidget);
    });

    testWidgets('ShopTabGuideDialog renders without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShopTabGuideDialog()),
        ),
      );
      await tester.pump();

      expect(find.text('TIENDA'), findsOneWidget);
      expect(find.text('Filtros por categoría'), findsOneWidget);
    });
  });
}
