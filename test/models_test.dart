import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/models/pasta_model.dart';

void main() {
  test('PastaModel ida e volta em JSON', () {
    final p = PastaModel(
      id: '1',
      nome: 'Rock',
      ehFavoritos: false,
      musicas: [MusicaRef(id: 7, titulo: 'A', artista: 'B', duracao: 1000)],
    );
    final volta = PastaModel.fromJson(jsonDecode(jsonEncode(p.toJson())));
    expect(volta.nome, 'Rock');
    expect(volta.ehFavoritos, isFalse);
    expect(volta.musicas.single.id, 7);
    expect(volta.musicas.single.titulo, 'A');
    expect(volta.musicas.single.duracao, 1000);
  });

  test('copyWith troca só o que foi passado', () {
    final p = PastaModel(
      id: '1',
      nome: 'Rock',
      ehFavoritos: false,
      musicas: [],
    );
    final r = p.copyWith(nome: 'Pop');
    expect(r.nome, 'Pop');
    expect(r.id, '1');
  });
}
