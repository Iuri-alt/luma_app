import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/biblioteca_screen.dart';
import 'package:luma_app/main.dart';
import 'package:luma_app/main_screen.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<ConfiguracoesService> _montar(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final pastaService = PastaService();
  await pastaService.carregar();
  final config = ConfiguracoesService();
  await config.carregar();

  await tester.pumpWidget(
    MyApp(
      musicaService: MusicaServiceFalso(),
      pastaService: pastaService,
      playerService: PlayerServiceFalso(config),
      configuracoesService: config,
      equalizadorService: EqualizadorService(
        nativo: NativoFalso(),
        configuracoes: config,
      ),
    ),
  );
  // Passa da splash
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  return config;
}

void main() {
  testWidgets('app abre direto na biblioteca, sem login', (tester) async {
    await _montar(tester);
    expect(find.text('Login'), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('trocar o tema redesenha o app sem perder a aba', (tester) async {
    final config = await _montar(tester);
    await config.definirTemaEscuro(false);
    await tester.pumpAndSettle();
    final fundo = tester
        .widget<Scaffold>(
          find
              .descendant(
                of: find.byType(BibliotecaScreen),
                matching: find.byType(Scaffold),
              )
              .first,
        )
        .backgroundColor;
    expect(fundo, AppColors.background);
    expect(AppColors.escuro, isFalse);
    expect(find.byType(MainScreen), findsOneWidget);
  });

  testWidgets('barra de status acompanha o tema do app', (tester) async {
    final config = await _montar(tester);
    SystemUiOverlayStyle estilo() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value;
    expect(estilo().statusBarIconBrightness, Brightness.light);
    await config.definirTemaEscuro(false);
    await tester.pumpAndSettle();
    expect(estilo().statusBarIconBrightness, Brightness.dark);
  });
}
