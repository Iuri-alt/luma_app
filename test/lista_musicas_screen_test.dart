import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/lista_musicas_screen.dart';
import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final _album = AlbumDispositivoModel(
  id: 1,
  nome: 'Abbey Road',
  artista: 'The Beatles',
  quantidadeMusicas: 2,
);

Future<PastaService> _pastas() async {
  SharedPreferences.setMockInitialValues({});
  final s = PastaService();
  await s.carregar();
  return s;
}

void main() {
  testWidgets('favoritar pelo menu muda o texto', (tester) async {
    final pastas = await _pastas();
    final musicas = MusicaServiceFalso(musicas: [musicaFalsa(10, 'Something')]);
    await tester.pumpWidget(
      MaterialApp(
        home: ListaMusicasScreen.album(
          album: _album,
          musicaService: musicas,
          pastaService: pastas,
          playerService: PlayerServiceFalso(),
          aoIniciarReproducao: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Abbey Road'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritar'));
    await tester.pumpAndSettle();
    expect(pastas.ehFavorito(10), isTrue);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Desfavoritar'), findsOneWidget);
    expect(find.text('Remover da playlist'), findsNothing);
  });

  testWidgets('remover da playlist', (tester) async {
    final pastas = await _pastas();
    final musica = musicaFalsa(10, 'Something');
    final p = await pastas.criar('Rock');
    await pastas.adicionarMusica(p.id, musica);
    await tester.pumpWidget(
      MaterialApp(
        home: ListaMusicasScreen.pasta(
          pastaId: p.id,
          musicaService: MusicaServiceFalso(musicas: [musica]),
          pastaService: pastas,
          playerService: PlayerServiceFalso(),
          aoIniciarReproducao: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover da playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música ainda'), findsOneWidget);
  });

  testWidgets('adicionar à playlist escolhe da lista', (tester) async {
    final pastas = await _pastas();
    final p = await pastas.criar('Treino');
    await tester.pumpWidget(
      MaterialApp(
        home: ListaMusicasScreen.album(
          album: _album,
          musicaService: MusicaServiceFalso(
            musicas: [musicaFalsa(10, 'Something')],
          ),
          pastaService: pastas,
          playerService: PlayerServiceFalso(),
          aoIniciarReproducao: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar à playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Treino'));
    await tester.pumpAndSettle();
    expect(pastas.pasta(p.id)!.musicas.single.id, 10);
  });

  testWidgets('tocar chama tocarFila com índice certo e avisa', (tester) async {
    final player = PlayerServiceFalso();
    var avisou = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ListaMusicasScreen.album(
          album: _album,
          musicaService: MusicaServiceFalso(
            musicas: [
              musicaFalsa(1, 'A primeira'),
              musicaFalsa(2, 'B segunda'),
            ],
          ),
          pastaService: await _pastas(),
          playerService: player,
          aoIniciarReproducao: () => avisou = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('B segunda'));
    await tester.pumpAndSettle();
    expect(player.indiceTocado, 1);
    expect(player.filaTocada!.length, 2);
    expect(avisou, isTrue);
  });
}
