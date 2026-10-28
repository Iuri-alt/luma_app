import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/services/armazenamento_service.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

class _ArmazenamentoFalso extends ArmazenamentoService {
  int pedidos = 0;
  final resposta = Completer<bool>();
  final ordem = <String>[];

  @override
  Future<void> solicitarNotificacoes() async => ordem.add('notificacoes');

  @override
  Future<bool> verificarPermissao() async => false;

  @override
  Future<bool> solicitarPermissao() {
    pedidos++;
    ordem.add('musica');
    return resposta.future;
  }
}

class _ConsultaFalsa extends OnAudioQuery {
  @override
  Future<List<SongModel>> querySongs({
    SongSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
    String? path,
  }) async => [
    SongModel({
      '_id': 1,
      'title': 'Faixa',
      'artist': '<unknown>',
      'album': null,
      '_data': '/m/1.mp3',
      'duration': 1000,
      '_size': 10,
      'album_id': 7,
      'is_music': true,
    }),
    SongModel({
      '_id': 2,
      'title': 'Toque',
      'artist': 'X',
      'album': 'Y',
      '_data': '/m/2.ogg',
      'duration': 500,
      '_size': 5,
      'album_id': 8,
      'is_music': false,
    }),
  ];

  @override
  Future<List<AlbumModel>> queryAlbums({
    AlbumSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
  }) async => [
    AlbumModel({'_id': 7, 'album': '<unknown>', 'artist': null, 'numsongs': 4}),
    AlbumModel({'_id': 8, 'album': 'Toques', 'artist': 'X', 'numsongs': 1}),
  ];
}

class _ArmazenamentoComMusicas extends ArmazenamentoService {
  final consulta = _ConsultaFalsa();

  @override
  Future<void> solicitarNotificacoes() async {}

  @override
  Future<bool> verificarPermissao() async => true;

  @override
  OnAudioQuery get audioQuery => consulta;
}

void main() {
  test('dois pedidos de permissão ao mesmo tempo viram um só', () async {
    final armazenamento = _ArmazenamentoFalso();
    final service = MusicaService(armazenamento: armazenamento);
    final a = service.garantirPermissao();
    final b = service.garantirPermissao();
    await Future<void>.delayed(Duration.zero);
    armazenamento.resposta.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(armazenamento.pedidos, 1);
  });

  test(
    'buscarMusicas tira toques e troca <unknown> por Desconhecido',
    () async {
      final service = MusicaService(armazenamento: _ArmazenamentoComMusicas());
      final musicas = await service.buscarMusicas();
      expect(musicas.map((m) => m.id), [1]);
      expect(musicas.single.artista, 'Artista Desconhecido');
      expect(musicas.single.album, 'Álbum Desconhecido');
      expect(musicas.single.albumId, 7);
    },
  );

  test('buscarAlbuns conta só músicas e some com álbum só de toques', () async {
    final service = MusicaService(armazenamento: _ArmazenamentoComMusicas());
    final albuns = await service.buscarAlbuns();
    expect(albuns.single.id, 7);
    expect(albuns.single.nome, 'Álbum Desconhecido');
    expect(albuns.single.artista, 'Artista Desconhecido');
    expect(albuns.single.quantidadeMusicas, 1);
  });

  test('pede notificações depois da música, uma vez só', () async {
    final armazenamento = _ArmazenamentoFalso();
    final service = MusicaService(armazenamento: armazenamento);
    final a = service.garantirPermissao();
    final b = service.garantirPermissao();
    await Future<void>.delayed(Duration.zero);
    expect(armazenamento.ordem, ['musica']);
    armazenamento.resposta.complete(true);
    await Future.wait([a, b]);
    expect(armazenamento.ordem, ['musica', 'notificacoes']);
  });
}
