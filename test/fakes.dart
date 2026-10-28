import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/models/musica_model.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/services/player_service.dart';

MusicaModel musicaFalsa(int id, String titulo, {int albumId = 1}) =>
    MusicaModel(
      id: id,
      titulo: titulo,
      artista: 'Artista',
      album: 'Álbum',
      caminho: '/$id.mp3',
      duracao: 180000,
      tamanho: 1,
      albumId: albumId,
    );

class MusicaServiceFalso extends MusicaService {
  MusicaServiceFalso({
    this.permitido = true,
    this.falhar = false,
    List<AlbumDispositivoModel>? albuns,
    List<MusicaModel>? musicas,
  }) : albuns =
           albuns ??
           [
             AlbumDispositivoModel(
               id: 1,
               nome: 'Abbey Road',
               artista: 'The Beatles',
               quantidadeMusicas: 1,
             ),
           ],
       musicas = musicas ?? [musicaFalsa(10, 'Come Together')];

  bool permitido;
  bool falhar;
  final List<AlbumDispositivoModel> albuns;
  final List<MusicaModel> musicas;

  @override
  Future<bool> garantirPermissao() async => permitido;

  // Simula a biblioteca terminando de ler as músicas de novo
  void avisarRecarga() => notifyListeners();

  @override
  Future<List<MusicaModel>> buscarMusicas() async => permitido ? musicas : [];

  @override
  Future<List<AlbumDispositivoModel>> buscarAlbuns() async {
    if (falhar) throw Exception('plugin falhou');
    return permitido ? albuns : [];
  }
}

class PlayerServiceFalso extends PlayerService {
  PlayerServiceFalso([ConfiguracoesService? configuracoes])
    : this._(configuracoes ?? ConfiguracoesService());

  PlayerServiceFalso._(this.configuracoesFalsas)
    : super(configuracoes: configuracoesFalsas);

  final ConfiguracoesService configuracoesFalsas;

  List<MusicaModel>? filaTocada;
  int? indiceTocado;
  MusicaModel? _atual;

  @override
  MusicaModel? get atual => _atual;

  @override
  bool get tocando => _atual != null;

  @override
  Stream<Duration> get posicao => const Stream.empty();

  Duration duracao = Duration.zero;
  final buscas = <Duration>[];

  @override
  Duration get duracaoAtual => duracao;

  @override
  Future<void> irPara(Duration posicao) async => buscas.add(posicao);

  @override
  Future<void> tocarFila(List<MusicaModel> fila, int indice) async {
    filaTocada = fila;
    indiceTocado = indice;
    _atual = fila[indice];
    notifyListeners();
  }

  @override
  Future<void> alternarPlayPause() async {}

  @override
  Future<void> alternarRepetir() async {
    await configuracoesFalsas.definirRepetir(
      ModoRepetir.values[(repetir.index + 1) % ModoRepetir.values.length],
    );
    notifyListeners();
  }

  @override
  Future<void> alternarAleatorio() async {
    await configuracoesFalsas.definirAleatorio(!aleatorio);
    notifyListeners();
  }
}

class NativoFalso implements EqualizadorNativo {
  bool ligado = false;
  final ganhos = <int, double>{};
  int pedidosDeParametros = 0;

  @override
  Future<ParametrosEq> parametros() async {
    pedidosDeParametros++;
    return const ParametrosEq(
      frequencias: [60, 230, 910, 3600, 14000],
      minimo: -15,
      maximo: 15,
    );
  }

  @override
  Future<void> ligar(bool valor) async => ligado = valor;

  @override
  Future<void> definirGanho(int banda, double db) async => ganhos[banda] = db;
}
