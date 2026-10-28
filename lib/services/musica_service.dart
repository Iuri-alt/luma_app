import 'package:flutter/foundation.dart';

import 'armazenamento_service.dart';
import '../functions/luma_functions.dart';
import '../models/album_dispositivo_model.dart';
import '../models/musica_model.dart';

// Avisa os ouvintes quando termina de ler as músicas do aparelho
class MusicaService extends ChangeNotifier {
  MusicaService({ArmazenamentoService? armazenamento})
    : _armazenamentoService = armazenamento ?? ArmazenamentoService();

  final ArmazenamentoService _armazenamentoService;

  // Cache em memória da última leitura do aparelho
  List<MusicaModel>? _musicas;
  // Pedido de permissão em andamento. Duas telas pedindo juntas derrubavam
  // o app ("Reply already submitted" no on_audio_query).
  Future<bool>? _pedidoPermissao;

  Future<bool> garantirPermissao() {
    return _pedidoPermissao ??= _pedirPermissao().whenComplete(
      () => _pedidoPermissao = null,
    );
  }

  Future<bool> _pedirPermissao() async {
    // Verificar permissões de armazenamento e pedir se ainda não tiver
    final permitido =
        await _armazenamentoService.verificarPermissao() ||
        await _armazenamentoService.solicitarPermissao();
    // Notificações só depois: dois pedidos ao mesmo tempo derrubam o app
    if (permitido) {
      try {
        await _armazenamentoService.solicitarNotificacoes();
      } catch (_) {
        // Sem notificação a música ainda toca
      }
    }
    return permitido;
  }

  void recarregar() => _musicas = null;

  Future<List<MusicaModel>> buscarMusicas() async {
    if (_musicas != null) return _musicas!;
    if (!await garantirPermissao()) {
      return [];
    }

    final musicas = await _armazenamentoService.audioQuery.querySongs();

    // Só músicas (tira toques, notificações e áudios de mensagem)
    _musicas = musicas.where((musica) => musica.isMusic == true).map((musica) {
      return MusicaModel(
        id: musica.id,
        titulo: musica.title,
        artista: _ouPadrao(musica.artist, 'Artista Desconhecido'),
        album: _ouPadrao(musica.album, 'Álbum Desconhecido'),
        caminho: musica.data,
        duracao: musica.duration ?? 0,
        tamanho: musica.size,
        albumId: musica.albumId,
      );
    }).toList();
    notifyListeners();
    return _musicas!;
  }

  Future<List<AlbumDispositivoModel>> buscarAlbuns() async {
    if (!await garantirPermissao()) {
      return [];
    }

    final musicas = await buscarMusicas();
    final albuns = await _armazenamentoService.audioQuery.queryAlbums();
    final lidos = albuns.map((album) {
      return AlbumDispositivoModel(
        id: album.id,
        nome: _ouPadrao(album.album, 'Álbum Desconhecido'),
        artista: _ouPadrao(album.artist, 'Artista Desconhecido'),
        quantidadeMusicas: album.numOfSongs,
      );
    }).toList();
    return ajustarContagemAlbuns(lidos, musicas);
  }

  List<MusicaModel> musicasDoAlbum(List<MusicaModel> todas, int albumId) {
    return todas.where((m) => m.albumId == albumId).toList()..sort(
      (a, b) => normalizarTexto(a.titulo).compareTo(normalizarTexto(b.titulo)),
    );
  }

  // Valor vazio ou '<unknown>' (padrão do Android) vira o texto padrão
  String _ouPadrao(String? valor, String padrao) {
    if (valor == null || valor.trim().isEmpty || valor == '<unknown>') {
      return padrao;
    }
    return valor;
  }
}
