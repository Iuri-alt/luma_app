import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

// AudioPlayer falso: só o que o PlayerService usa
class _PlayerFalso extends Fake implements AudioPlayer {
  final erros = StreamController<PlayerException>.broadcast();
  int pulos = 0;
  int plays = 0;
  final carregando = <Completer<void>>[];
  bool segurarCarga = false;
  bool falharCarga = false;
  final loops = <LoopMode>[];
  final embaralhar = <bool>[];

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loops.add(mode);
    modoAgora = mode;
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async =>
      embaralhar.add(enabled);
  @override
  Future<void> shuffle() async {}

  @override
  Stream<PlayerException> get errorStream => erros.stream;
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  final saltos = StreamController<PositionDiscontinuity>.broadcast();
  @override
  Stream<PositionDiscontinuity> get positionDiscontinuityStream =>
      saltos.stream;
  final estados = StreamController<PlayerState>.broadcast();
  @override
  Stream<PlayerState> get playerStateStream => estados.stream;
  bool tocandoAgora = false;
  @override
  bool get playing => tocandoAgora;
  ProcessingState estadoAgora = ProcessingState.ready;
  @override
  ProcessingState get processingState => estadoAgora;
  int? indiceAgora = 0;
  @override
  int? get currentIndex => indiceAgora;
  List<int> ordem = [0, 1, 2];
  @override
  List<int> get effectiveIndices => ordem;
  LoopMode modoAgora = LoopMode.off;
  @override
  LoopMode get loopMode => modoAgora;
  final buscas = <(Duration, int?)>[];
  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      buscas.add((position ?? Duration.zero, index));
  @override
  Duration get position => Duration.zero;
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  bool proximaExiste = true;
  @override
  bool get hasNext => proximaExiste;
  @override
  Future<void> seekToNext() async => pulos++;
  @override
  Future<void> play() async => plays++;
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    if (falharCarga) {
      erros.add(PlayerException(1, 'não abre', initialIndex));
      throw PlayerException(1, 'não abre', initialIndex);
    }
    if (segurarCarga) {
      final c = Completer<void>();
      carregando.add(c);
      await c.future;
    }
    return null;
  }
}

PlaybackEvent _evento(int indice) => PlaybackEvent(currentIndex: indice);

void main() {
  late ConfiguracoesService config;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    config = ConfiguracoesService();
    await config.carregar();
  });

  test('erro no meio da fila avisa e pula para a próxima', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    final mensagens = <String>[];
    service.erros.listen(mensagens.add);

    await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
    falso.erros.add(PlayerException(1, 'arquivo sumiu', 1));
    await Future<void>.delayed(Duration.zero);

    expect(mensagens, [PlayerService.mensagemErro]);
    expect(falso.pulos, 1);
  });

  test('toques rápidos: só a última música escolhida toca', () async {
    final falso = _PlayerFalso()..segurarCarga = true;
    final service = PlayerService(player: falso, configuracoes: config);
    final primeira = service.tocarFila([musicaFalsa(1, 'A')], 0);
    final segunda = service.tocarFila([musicaFalsa(2, 'B')], 0);
    await Future<void>.delayed(Duration.zero);
    falso.carregando[1].complete();
    await segunda;
    falso.carregando[0].complete();
    await primeira;
    expect(falso.plays, 1);
    expect(service.atual!.id, 2);
  });

  test('repetir alterna desligado, fila, música e aplica no player', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.alternarRepetir();
    expect(service.repetir, ModoRepetir.fila);
    await service.alternarRepetir();
    expect(service.repetir, ModoRepetir.musica);
    await service.alternarRepetir();
    expect(service.repetir, ModoRepetir.desligado);
    // "música" usa LoopMode.all no player; a repetição é feita pelo app
    expect(falso.loops, [LoopMode.all, LoopMode.all, LoopMode.off]);
    expect(config.repetir, ModoRepetir.desligado);
  });

  test('aleatório liga no player e fica salvo', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.alternarAleatorio();
    expect(service.aleatorio, isTrue);
    expect(falso.embaralhar.last, isTrue);
    expect(config.aleatorio, isTrue);
  });

  test('tocarFila aplica modos salvos', () async {
    await config.definirAleatorio(true);
    await config.definirRepetir(ModoRepetir.musica);
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.tocarFila([musicaFalsa(1, 'A')], 0);
    expect(falso.loops.last, LoopMode.all);
    expect(falso.embaralhar.last, isTrue);
  });

  test('EQ que falha ou trava não impede a música de tocar', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(
      player: falso,
      configuracoes: config,
      aoPrepararAudio: () => Completer<void>().future,
    );
    await service.tocarFila([musicaFalsa(1, 'A')], 0);
    expect(falso.plays, 1);

    final falso2 = _PlayerFalso();
    final service2 = PlayerService(
      player: falso2,
      configuracoes: config,
      aoPrepararAudio: () async => throw Exception('sem EQ'),
    );
    final mensagens = <String>[];
    service2.erros.listen(mensagens.add);
    await service2.tocarFila([musicaFalsa(1, 'A')], 0);
    await Future<void>.delayed(Duration.zero);
    expect(falso2.plays, 1);
    expect(mensagens, isEmpty);
  });

  test('fila toda com erro e repetir ligado não pula para sempre', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
    for (var i = 0; i < 6; i++) {
      falso.erros.add(PlayerException(1, 'erro $i', i % 2));
      await Future<void>.delayed(Duration.zero);
    }
    // A 1ª falha pula para a 2ª; a 2ª falha e para (todas já tentadas)
    expect(falso.pulos, 1);
  });

  test('falha ao carregar avisa e pula uma vez só', () async {
    final falso = _PlayerFalso()..falharCarga = true;
    final service = PlayerService(player: falso, configuracoes: config);
    final mensagens = <String>[];
    service.erros.listen(mensagens.add);
    await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
    await Future<void>.delayed(Duration.zero);
    expect(mensagens.length, 1);
    expect(falso.pulos, 1);
  });

  test(
    'mesma música falhando de novo depois de tocar outra avisa de novo',
    () async {
      final falso = _PlayerFalso();
      final service = PlayerService(player: falso, configuracoes: config);
      final mensagens = <String>[];
      service.erros.listen(mensagens.add);
      await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
      falso.erros.add(PlayerException(1, 'A quebrada', 0));
      await Future<void>.delayed(Duration.zero);
      falso.estados.add(PlayerState(true, ProcessingState.ready));
      await Future<void>.delayed(Duration.zero);
      falso.erros.add(PlayerException(1, 'A quebrada de novo', 0));
      await Future<void>.delayed(Duration.zero);
      expect(mensagens.length, 2);
    },
  );

  test('fim da fila mostra play e tocar de novo recomeça do início', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.tocarFila([
      musicaFalsa(1, 'A'),
      musicaFalsa(2, 'B'),
      musicaFalsa(3, 'C'),
    ], 2);
    falso.estados.add(PlayerState(true, ProcessingState.ready));
    await Future<void>.delayed(Duration.zero);
    expect(service.tocando, isTrue);
    falso
      ..tocandoAgora = true
      ..estadoAgora = ProcessingState.completed;
    falso.estados.add(PlayerState(true, ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);
    expect(service.tocando, isFalse);
    final playsAntes = falso.plays;
    await service.alternarPlayPause();
    expect(falso.buscas.last, (Duration.zero, 0));
    expect(falso.plays, playsAntes + 1);
  });

  test('com repetir uma, música que termina sozinha volta ao começo', () async {
    final falso = _PlayerFalso();
    final service = PlayerService(player: falso, configuracoes: config);
    await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
    await service.alternarRepetir();
    await service.alternarRepetir();
    expect(service.repetir, ModoRepetir.musica);
    falso.saltos.add(
      PositionDiscontinuity(
        PositionDiscontinuityReason.autoAdvance,
        _evento(0),
        _evento(1),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(falso.buscas.last, (Duration.zero, 0));
  });

  test(
    'com repetir uma, próxima (app ou notificação) troca de música',
    () async {
      final falso = _PlayerFalso();
      final service = PlayerService(player: falso, configuracoes: config);
      await service.tocarFila([musicaFalsa(1, 'A'), musicaFalsa(2, 'B')], 0);
      await config.definirRepetir(ModoRepetir.musica);
      await service.proxima();
      expect(falso.pulos, 1);
      falso.saltos.add(
        PositionDiscontinuity(
          PositionDiscontinuityReason.seek,
          _evento(0),
          _evento(1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(falso.buscas, isEmpty);
    },
  );
}
