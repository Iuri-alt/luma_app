import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/biblioteca_screen.dart';
import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

AlbumDispositivoModel _album(int id, String nome) => AlbumDispositivoModel(
  id: id,
  nome: nome,
  artista: 'Artista',
  quantidadeMusicas: 2,
);

Future<PastaService> _pastas() async {
  SharedPreferences.setMockInitialValues({});
  final s = PastaService();
  await s.carregar();
  return s;
}

Future<void> _abrir(
  WidgetTester tester,
  PastaService pastas, {
  MusicaServiceFalso? musicas,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BibliotecaScreen(
        musicaService:
            musicas ??
            MusicaServiceFalso(
              albuns: [_album(1, 'Abbey Road'), _album(2, 'Zé Ramalho')],
            ),
        pastaService: pastas,
        playerService: PlayerServiceFalso(),
        aoIniciarReproducao: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra Favoritos, playlists e álbuns agrupados', (tester) async {
    final pastas = await _pastas();
    await pastas.criar('Treino');
    await _abrir(tester, pastas);
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Treino'), findsOneWidget);
    expect(find.text('Abbey Road'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);
    expect(find.text('2 músicas'), findsWidgets);
  });

  testWidgets('busca filtra sem acento', (tester) async {
    await _abrir(tester, await _pastas());
    await tester.enterText(find.byType(TextField), 'ze');
    await tester.pumpAndSettle();
    expect(find.text('Zé Ramalho'), findsOneWidget);
    expect(find.text('Abbey Road'), findsNothing);
  });

  testWidgets('busca sem resultado avisa', (tester) async {
    await _abrir(tester, await _pastas());
    await tester.enterText(find.byType(TextField), 'xyzw');
    await tester.pumpAndSettle();
    expect(find.text('Nada encontrado'), findsOneWidget);
  });

  testWidgets('cria playlist pelo diálogo e recusa vazio', (tester) async {
    await _abrir(tester, await _pastas());
    await tester.tap(find.text('Nova playlist'));
    await tester.pumpAndSettle();
    final criar = find.widgetWithText(TextButton, 'Criar');
    expect(tester.widget<TextButton>(criar).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.pump();
    expect(tester.widget<TextButton>(criar).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Foco');
    await tester.pump();
    await tester.tap(criar);
    await tester.pumpAndSettle();
    expect(find.text('Foco'), findsOneWidget);
  });

  testWidgets('excluir playlist pede confirmação', (tester) async {
    final pastas = await _pastas();
    await pastas.criar('Velha');
    await _abrir(tester, pastas);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir playlist?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Velha'), findsNothing);
    expect(pastas.playlists, isEmpty);
  });

  testWidgets('permissão negada mostra botão', (tester) async {
    final musicas = MusicaServiceFalso(permitido: false);
    await _abrir(tester, await _pastas(), musicas: musicas);
    expect(find.text('Permitir acesso'), findsOneWidget);
    musicas.permitido = true;
    await tester.tap(find.text('Permitir acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Abbey Road'), findsOneWidget);
  });

  testWidgets('permissão negada de novo explica como liberar', (tester) async {
    await _abrir(
      tester,
      await _pastas(),
      musicas: MusicaServiceFalso(permitido: false),
    );
    expect(find.textContaining('Configurações'), findsNothing);
    await tester.tap(find.text('Permitir acesso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Configurações'), findsOneWidget);
  });

  testWidgets('erro ao ler músicas mostra tentar de novo', (tester) async {
    final musicas = MusicaServiceFalso(falhar: true);
    await _abrir(tester, await _pastas(), musicas: musicas);
    expect(find.text('Não foi possível ler suas músicas'), findsOneWidget);
    musicas.falhar = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Abbey Road'), findsOneWidget);
  });

  testWidgets('puxar para baixo atualiza a lista', (tester) async {
    final musicas = MusicaServiceFalso(albuns: [_album(1, 'Abbey Road')]);
    await _abrir(tester, await _pastas(), musicas: musicas);
    expect(find.text('Help!'), findsNothing);
    musicas.albuns.add(_album(3, 'Help!'));
    await tester.fling(find.text('Abbey Road'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Help!'), findsOneWidget);
  });
}
