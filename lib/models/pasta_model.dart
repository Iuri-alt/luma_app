import 'musica_model.dart';

// Referência salva de uma música. Guarda metadados além do id
// porque o id do MediaStore pode mudar (arquivo movido, novo celular).
class MusicaRef {
  final int id;
  final String titulo;
  final String artista;
  final int duracao;

  MusicaRef({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.duracao,
  });

  factory MusicaRef.deMusica(MusicaModel m) => MusicaRef(
    id: m.id,
    titulo: m.titulo,
    artista: m.artista,
    duracao: m.duracao,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'artista': artista,
    'duracao': duracao,
  };

  factory MusicaRef.fromJson(Map<String, dynamic> json) => MusicaRef(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    artista: json['artista'] as String,
    duracao: json['duracao'] as int,
  );
}

// Playlist criada pelo usuário (ou a playlist especial Favoritos)
class PastaModel {
  final String id;
  final String nome;
  final List<MusicaRef> musicas;
  final bool ehFavoritos;

  PastaModel({
    required this.id,
    required this.nome,
    required this.musicas,
    required this.ehFavoritos,
  });

  PastaModel copyWith({String? nome, List<MusicaRef>? musicas}) => PastaModel(
    id: id,
    nome: nome ?? this.nome,
    musicas: musicas ?? this.musicas,
    ehFavoritos: ehFavoritos,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'ehFavoritos': ehFavoritos,
    'musicas': musicas.map((m) => m.toJson()).toList(),
  };

  factory PastaModel.fromJson(Map<String, dynamic> json) => PastaModel(
    id: json['id'] as String,
    nome: json['nome'] as String,
    ehFavoritos: json['ehFavoritos'] as bool? ?? false,
    musicas: (json['musicas'] as List<dynamic>? ?? [])
        .map((m) => MusicaRef.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}
