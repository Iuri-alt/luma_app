import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/widgets/painel_equalizador.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late EqualizadorService eq;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final config = ConfiguracoesService();
    await config.carregar();
    eq = EqualizadorService(nativo: NativoFalso(), configuracoes: config);
  });

  Future<void> abrir(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PainelEqualizador(equalizadorService: eq),
        ),
      ),
    ),
  );

  testWidgets('antes de tocar música explica o que fazer', (tester) async {
    await abrir(tester);
    expect(
      find.text('Toque uma música para ajustar o equalizador'),
      findsOneWidget,
    );
  });

  testWidgets('mostra bandas, liga e escolhe preset', (tester) async {
    await eq.preparar();
    await abrir(tester);
    expect(find.text('60 Hz'), findsOneWidget);
    expect(find.text('3,6 kHz'), findsOneWidget);
    expect(find.text('14 kHz'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(eq.ligado, isTrue);
    await tester.tap(find.text('Rock'));
    await tester.pump();
    expect(eq.preset, 'Rock');
    expect(find.text('+5 dB'), findsNWidgets(2));
  });

  testWidgets('arrastar banda vira Personalizado', (tester) async {
    await eq.preparar();
    await abrir(tester);
    await tester.drag(find.byType(Slider).first, const Offset(0, -40));
    await tester.pump();
    expect(eq.preset, 'Personalizado');
    expect(eq.ganhos.first, greaterThan(0));
  });

  testWidgets('arrastar banda salva só ao soltar', (tester) async {
    await eq.preparar();
    await abrir(tester);
    var avisos = 0;
    eq.configuracoes.addListener(() => avisos++);
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(Slider).first),
    );
    for (var i = 0; i < 5; i++) {
      await gesto.moveBy(const Offset(0, -10));
      await tester.pump();
    }
    expect(avisos, 0);
    expect(eq.ganhos.first, greaterThan(0));
    await gesto.up();
    await tester.pump();
    expect(avisos, 1);
    expect(eq.configuracoes.eqGanhos.first, eq.ganhos.first);
  });
}
