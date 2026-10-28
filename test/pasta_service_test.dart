import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/models/musica_model.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

MusicaModel musica(int id) => MusicaModel(
  id: id,
  titulo: 'M$id',
  artista: 'A',
  album: 'B',
  caminho: '/$id',
  duracao: 1000,
  tamanho: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('começa só com Favoritos', () async {
    final s = PastaService();
    await s.carregar();
    expect(s.favoritos.id, 'favoritos');
    expect(s.favoritos.nome, 'Favoritos');
    expect(s.playlists, isEmpty);
  });

  test('cria, renomeia, adiciona sem duplicar, remove e exclui', () async {
    final s = PastaService();
    await s.carregar();
    final p = await s.criar('  Rock  ');
    expect(p.nome, 'Rock');
    await s.renomear(p.id, 'Rock BR');
    expect(s.playlists.single.nome, 'Rock BR');
    await s.adicionarMusica(p.id, musica(1));
    await s.adicionarMusica(p.id, musica(1));
    expect(s.playlists.single.musicas.length, 1);
    await s.removerMusica(p.id, 1);
    expect(s.playlists.single.musicas, isEmpty);
    await s.excluir(p.id);
    expect(s.playlists, isEmpty);
  });

  test('persiste entre instâncias', () async {
    final a = PastaService();
    await a.carregar();
    await a.criar('Treino');
    await a.alternarFavorito(musica(3));
    final b = PastaService();
    await b.carregar();
    expect(b.playlists.single.nome, 'Treino');
    expect(b.ehFavorito(3), isTrue);
  });

  test('alternarFavorito liga e desliga', () async {
    final s = PastaService();
    await s.carregar();
    await s.alternarFavorito(musica(3));
    await s.alternarFavorito(musica(3));
    expect(s.ehFavorito(3), isFalse);
  });

  test('recusa nome vazio e protege Favoritos', () async {
    final s = PastaService();
    await s.carregar();
    expect(() => s.criar('   '), throwsArgumentError);
    expect(() => s.excluir('favoritos'), throwsArgumentError);
    expect(() => s.renomear('favoritos', 'X'), throwsArgumentError);
  });

  test('JSON corrompido não trava e guarda backup', () async {
    SharedPreferences.setMockInitialValues({PastaService.chave: '{quebrado'});
    final s = PastaService();
    await s.carregar();
    expect(s.favoritos.musicas, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('luma_pastas_v1_backup'), '{quebrado');
  });

  test('avisa ouvintes quando muda', () async {
    final s = PastaService();
    await s.carregar();
    var avisos = 0;
    s.addListener(() => avisos++);
    await s.criar('X');
    expect(avisos, 1);
  });

  test('valor de tipo errado na chave não trava', () async {
    SharedPreferences.setMockInitialValues({PastaService.chave: 42});
    final s = PastaService();
    await s.carregar();
    expect(s.favoritos.id, 'favoritos');
  });
}
