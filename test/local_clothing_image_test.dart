import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/local_clothing_image.dart';

void main() {
  testWidgets('uses a placeholder for an empty local image path', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocalClothingImage(
          imagePath: null,
          width: 160,
          height: 120,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('local-clothing-image-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('uses a placeholder for a missing local image file', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocalClothingImage(
          imagePath: 'missing/wardrobe-image.jpg',
          width: 160,
          height: 120,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('local-clothing-image-placeholder')),
      findsOneWidget,
    );
  });
}
