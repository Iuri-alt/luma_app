import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/reproducao_screen.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/widgets/painel_equalizador.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late PastaService pastas;
  late PlayerServiceFalso player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pastas = PastaService();
    await pastas.carregar();
    player = PlayerServiceFalso();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReproducaoScreen(
          playerService: player,
          pastaService: pastas,
          equalizadorService: EqualizadorService(
            nativo: NativoFalso(),
            configuracoes: player.configuracoesFalsas,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sem música pede para escolher na biblioteca', (tester) async {
    await abrir(tester);
    expect(find.text('Escolha uma música na biblioteca'), findsOneWidget);
  });

  testWidgets('mostra música atual e coração favorita', (tester) async {
    await abrir(tester);
    await player.tocarFila([musicaFalsa(10, 'Something')], 0);
    await tester.pump();
    expect(find.text('Something'), findsOneWidget);
    expect(find.text('Artista · Álbum'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(pastas.ehFavorito(10), isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('arrastar o slider busca só ao soltar', (tester) async {
    await abrir(tester);
    player.duracao = const Duration(minutes: 3);
    await player.tocarFila([musicaFalsa(10, 'Something')], 0);
    await tester.pump();
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesto.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesto.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(player.buscas, isEmpty);
    await gesto.up();
    await tester.pump();
    expect(player.buscas.length, 1);
  });

  testWidgets('botões de aleatório e repetir mudam o modo', (tester) async {
    await abrir(tester);
    await player.tocarFila([musicaFalsa(10, 'Something')], 0);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    expect(player.aleatorio, isTrue);
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pump();
    expect(player.repetir, ModoRepetir.fila);
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pump();
    expect(player.repetir, ModoRepetir.musica);
    expect(find.byIcon(Icons.repeat_one), findsOneWidget);
  });

  testWidgets('botão do EQ abre o painel', (tester) async {
    await abrir(tester);
    await player.tocarFila([musicaFalsa(10, 'Something')], 0);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.equalizer));
    await tester.pumpAndSettle();
    expect(find.byType(PainelEqualizador), findsOneWidget);
    expect(find.text('Equalizador'), findsOneWidget);
  });
}
