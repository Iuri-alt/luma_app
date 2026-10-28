import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/models/musica_model.dart';
import 'package:luma_app/models/pasta_model.dart';
import 'package:luma_app/services/musica_service.dart';

MusicaModel _musica(int id, String titulo, {int duracao = 10, int? albumId}) =>
    MusicaModel(
      id: id,
      titulo: titulo,
      artista: 'Y',
      album: 'Z',
      caminho: '/$id',
      duracao: duracao,
      tamanho: 1,
      albumId: albumId,
    );

void main() {
  test('formatarDuracao usa mm:ss', () {
    expect(formatarDuracao(const Duration(minutes: 3, seconds: 7)), '03:07');
  });

  test('normalizarTexto tira acento e caixa', () {
    expect(normalizarTexto('Canção ÁGUA'), 'cancao agua');
  });

  test('agruparPorLetra usa letra sem acento e # por último', () {
    final g = agruparPorLetra(['Zeca', 'ábaco', '1999', 'Abba', ''], (s) => s);
    expect(g.keys.toList(), ['A', 'Z', '#']);
    expect(g['A'], ['ábaco', 'Abba']);
    expect(g['#'], containsAll(['1999', '']));
  });

  test(
    'resolverMusicas acha por id, depois por metadados, e mantém perdidas',
    () {
      final aparelho = [_musica(1, 'X'), _musica(99, 'Movida', duracao: 20)];
      final refs = [
        MusicaRef(id: 1, titulo: 'X', artista: 'Y', duracao: 10),
        MusicaRef(id: 5, titulo: 'Movida', artista: 'Y', duracao: 20),
        MusicaRef(id: 6, titulo: 'Sumiu', artista: 'Y', duracao: 30),
      ];
      final r = resolverMusicas(refs, aparelho);
      expect(r.encontradas.map((m) => m.id), [1, 99]);
      expect(r.refsAtualizadas.map((m) => m.id), [1, 99, 6]);
    },
  );

  test('musicasDoAlbum filtra pelo album e ordena por titulo', () {
    final todas = [
      _musica(1, 'Zebra', albumId: 5),
      _musica(2, 'Outra', albumId: 9),
      _musica(3, 'Água', albumId: 5),
    ];
    final r = MusicaService().musicasDoAlbum(todas, 5);
    expect(r.map((m) => m.id), [3, 1]);
  });

  test('ajustarContagemAlbuns conta só músicas e tira álbum vazio', () {
    final albuns = [
      AlbumDispositivoModel(
        id: 5,
        nome: 'A',
        artista: 'X',
        quantidadeMusicas: 12,
      ),
      AlbumDispositivoModel(
        id: 9,
        nome: 'B',
        artista: 'X',
        quantidadeMusicas: 3,
      ),
    ];
    final musicas = [_musica(1, 'a', albumId: 5), _musica(2, 'b', albumId: 5)];
    final r = ajustarContagemAlbuns(albuns, musicas);
    expect(r.single.id, 5);
    expect(r.single.quantidadeMusicas, 2);
  });

  test('formatarTamanho usa B, KB, MB e GB', () {
    expect(formatarTamanho(512), '512 B');
    expect(formatarTamanho(1536), '1,5 KB');
    expect(formatarTamanho(350 * 1024 * 1024), '350,0 MB');
    expect(formatarTamanho(1288490189), '1,2 GB');
  });

  test('ganhosDoPreset nas 5 bandas padrão usa a curva exata', () {
    expect(ganhosDoPreset('Rock', [60, 230, 910, 3600, 14000], -15, 15), [
      5,
      2,
      -2,
      2,
      5,
    ]);
    expect(
      ganhosDoPreset('Normal', [60, 230, 910, 3600, 14000], -15, 15),
      everyElement(0),
    );
  });

  test('ganhosDoPreset interpola outras bandas e respeita limites', () {
    final g = ganhosDoPreset('Grave', [30, 145, 14000], -3, 3);
    expect(g[0], 3); // abaixo de 60 Hz usa o valor de 60 Hz (6), limitado a 3
    expect(g[1], closeTo(3, 0.01)); // entre 6 e 4, limitado a 3
    expect(g[2], 0);
    expect(presetsEq.first, 'Normal');
  });

  test('formatarFrequencia usa Hz e kHz', () {
    expect(formatarFrequencia(60), '60 Hz');
    expect(formatarFrequencia(910), '910 Hz');
    expect(formatarFrequencia(3600), '3,6 kHz');
    expect(formatarFrequencia(14000), '14 kHz');
  });
}
