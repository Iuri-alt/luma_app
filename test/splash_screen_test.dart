import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/splash_screen.dart';

void main() {
  testWidgets('mostra o logo e depois abre a próxima tela', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          proximaTela: (_) => const Scaffold(body: Text('principal')),
        ),
      ),
    );
    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, 'lib/assets/luma_logo.png');
    expect(find.text('principal'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('principal'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
