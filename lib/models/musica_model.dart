class MusicaModel {
  final int id;
  final String titulo;
  final String artista;
  final String album;
  final String caminho;
  final int duracao;
  final int tamanho;
  final int? albumId;

  MusicaModel({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.album,
    required this.duracao,
    required this.caminho,
    required this.tamanho,
    this.albumId,
  });
}
