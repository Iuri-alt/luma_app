import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/config_screen.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/widgets/painel_equalizador.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late ConfiguracoesService config;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    config = ConfiguracoesService();
    await config.carregar();
    AppColors.escuro = true;
  });

  late MusicaServiceFalso musicas;

  Future<void> abrir(WidgetTester tester, {bool permitido = true}) async {
    musicas = MusicaServiceFalso(
      permitido: permitido,
      musicas: [musicaFalsa(1, 'A'), musicaFalsa(2, 'B')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigScreen(
          configuracoesService: config,
          musicaService: musicas,
          equalizadorService: EqualizadorService(
            nativo: NativoFalso(),
            configuracoes: config,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switch de tema troca a paleta e salva', (tester) async {
    await abrir(tester);
    final escuroFundo = AppColors.background;
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(config.temaEscuro, isFalse);
    expect(AppColors.escuro, isFalse);
    expect(AppColors.background, isNot(escuroFundo));
    expect(find.text('Claro'), findsOneWidget);
  });

  testWidgets('armazenamento mostra o tamanho real das músicas', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('2 músicas · 2 B'), findsOneWidget);
  });

  testWidgets('EQ expande e mostra o painel', (tester) async {
    await abrir(tester);
    expect(find.byType(PainelEqualizador), findsNothing);
    await tester.tap(find.text('EQ'));
    await tester.pumpAndSettle();
    expect(find.byType(PainelEqualizador), findsOneWidget);
  });

  testWidgets('armazenamento atualiza quando a biblioteca recarrega', (
    tester,
  ) async {
    await abrir(tester, permitido: false);
    expect(find.text('0 músicas · 0 B'), findsOneWidget);
    musicas.permitido = true;
    musicas.avisarRecarga();
    await tester.pumpAndSettle();
    expect(find.text('2 músicas · 2 B'), findsOneWidget);
  });
}
