import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/musica_model.dart';
import 'configuracoes_service.dart';

// Toca a fila atual (álbum ou playlist de onde a música foi aberta)
class PlayerService extends ChangeNotifier {
  static const mensagemErro = 'Não foi possível tocar esta música';

  PlayerService({
    AudioPlayer? player,
    this._criarPlayer,
    required this._configuracoes,
    this.aoPrepararAudio,
  }) : _playerInjetado = player;

  final AudioPlayer? _playerInjetado;
  final AudioPlayer Function()? _criarPlayer;
  final ConfiguracoesService _configuracoes;
  // Chamado depois que a fila carrega (o EQ só fica pronto aí)
  final Future<void> Function()? aoPrepararAudio;
  AudioPlayer? _playerCriado;
  final _erros = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _inscricoes = [];

  List<MusicaModel> _fila = [];
  int? _indice;
  bool _tocando = false;
  // Aumenta a cada pedido; pedidos antigos que terminam depois são ignorados
  int _pedido = 0;
  // Erros seguidos sem tocar nada; evita pular para sempre com repetir ligado
  int _falhasSeguidas = 0;
  // Uma falha pode chegar duas vezes (exceção + errorStream): trata só uma
  String? _ultimaFalha;

  // Criado no primeiro uso (na prática, ao abrir a tela de reprodução)
  AudioPlayer get _player {
    final existente = _playerCriado;
    if (existente != null) return existente;
    final novo = _playerInjetado ?? _criarPlayer?.call() ?? AudioPlayer();
    _playerCriado = novo;
    _ouvir(novo);
    return novo;
  }

  MusicaModel? get atual =>
      _indice != null && _indice! < _fila.length ? _fila[_indice!] : null;
  bool get tocando => _tocando;
  Stream<Duration> get posicao => _player.positionStream;
  Duration get duracaoAtual =>
      _player.duration ?? Duration(milliseconds: atual?.duracao ?? 0);
  Stream<String> get erros => _erros.stream;
  bool get aleatorio => _configuracoes.aleatorio;
  ModoRepetir get repetir => _configuracoes.repetir;

  Future<void> tocarFila(List<MusicaModel> fila, int indice) async {
    final pedido = ++_pedido;
    _falhasSeguidas = 0;
    _ultimaFalha = null;
    _fila = List.of(fila);
    _indice = indice;
    notifyListeners();
    try {
      await _player.setAudioSources([
        for (final m in _fila) AudioSource.file(m.caminho, tag: _mediaItem(m)),
      ], initialIndex: indice);
      if (pedido != _pedido) return;
      await _aplicarModos();
      if (pedido != _pedido) return;
      unawaited(_player.play());
      // EQ depois do play: se o aparelho não tiver EQ, a música toca mesmo assim
      final preparar = aoPrepararAudio;
      if (preparar != null) {
        unawaited(
          preparar()
              .timeout(const Duration(seconds: 3))
              .catchError((Object _) {}),
        );
      }
    } catch (_) {
      if (pedido == _pedido) await _falhou(indice);
    }
  }

  Future<void> alternarPlayPause() async {
    if (atual == null) return;
    // Fila acabou: recomeça da primeira (na ordem atual, com ou sem aleatório)
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: _player.effectiveIndices.first);
      unawaited(_player.play());
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> proxima() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> anterior() async {
    // Mais de 3 segundos tocados: volta ao começo da mesma música
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> irPara(Duration posicao) => _player.seek(posicao);

  // Desligado, depois repetir fila, depois repetir música
  Future<void> alternarRepetir() async {
    final proximo =
        ModoRepetir.values[(repetir.index + 1) % ModoRepetir.values.length];
    await _configuracoes.definirRepetir(proximo);
    await _player.setLoopMode(_loopMode(proximo));
    notifyListeners();
  }

  Future<void> alternarAleatorio() async {
    final ligar = !aleatorio;
    await _configuracoes.definirAleatorio(ligar);
    if (ligar) await _player.shuffle();
    await _player.setShuffleModeEnabled(ligar);
    notifyListeners();
  }

  Future<void> _aplicarModos() async {
    await _player.setLoopMode(_loopMode(repetir));
    if (aleatorio) await _player.shuffle();
    await _player.setShuffleModeEnabled(aleatorio);
  }

  LoopMode _loopMode(ModoRepetir modo) => switch (modo) {
    ModoRepetir.desligado => LoopMode.off,
    ModoRepetir.fila => LoopMode.all,
    // Não usa LoopMode.one: nele o "próxima" (app e notificação) repete a
    // mesma música. A repetição é feita em _ouvir, quando a música acaba.
    ModoRepetir.musica => LoopMode.all,
  };

  // Dados mostrados na notificação e na tela bloqueada
  MediaItem _mediaItem(MusicaModel m) => MediaItem(
    id: '${m.id}',
    title: m.titulo,
    artist: m.artista,
    album: m.album,
    duration: Duration(milliseconds: m.duracao),
    artUri: m.albumId == null
        ? null
        : Uri.parse('content://media/external/audio/albumart/${m.albumId}'),
  );

  void _ouvir(AudioPlayer player) {
    _inscricoes.add(
      player.currentIndexStream.listen((indice) {
        if (indice == null || indice == _indice) return;
        _indice = indice;
        notifyListeners();
      }),
    );
    _inscricoes.add(
      player.playerStateStream.listen((estado) {
        if (estado.playing && estado.processingState == ProcessingState.ready) {
          _falhasSeguidas = 0;
          _ultimaFalha = null;
        }
        // No fim da fila o just_audio continua com playing = true
        final tocando =
            estado.playing &&
            estado.processingState != ProcessingState.completed;
        if (tocando == _tocando) return;
        _tocando = tocando;
        notifyListeners();
      }),
    );
    // Repetir uma: música que acabou sozinha volta ao começo dela mesma
    _inscricoes.add(
      player.positionDiscontinuityStream.listen((salto) {
        if (repetir != ModoRepetir.musica) return;
        if (salto.reason != PositionDiscontinuityReason.autoAdvance) return;
        final anterior = salto.previousEvent.currentIndex;
        if (anterior != null) _player.seek(Duration.zero, index: anterior);
      }),
    );
    // No just_audio 0.10 os erros de faixa chegam só pelo errorStream
    _inscricoes.add(player.errorStream.listen((erro) => _falhou(erro.index)));
  }

  // Arquivo sumiu ou não abre: avisa e pula para a próxima, se houver
  Future<void> _falhou(int? indice) async {
    final chave = '$_pedido:${indice ?? _indice}';
    if (chave == _ultimaFalha) return;
    _ultimaFalha = chave;
    _erros.add(mensagemErro);
    final player = _playerCriado;
    if (player == null) return;
    _falhasSeguidas++;
    if (_falhasSeguidas >= _fila.length) return;
    if (player.hasNext) {
      await player.seekToNext();
      unawaited(player.play());
    }
  }

  @override
  void dispose() {
    for (final i in _inscricoes) {
      i.cancel();
    }
    _erros.close();
    _playerCriado?.dispose();
    super.dispose();
  }
}
