// Álbum lido do aparelho (somente leitura)
class AlbumDispositivoModel {
  final int id;
  final String nome;
  final String artista;
  final int quantidadeMusicas;

  AlbumDispositivoModel({
    required this.id,
    required this.nome,
    required this.artista,
    required this.quantidadeMusicas,
  });
}
