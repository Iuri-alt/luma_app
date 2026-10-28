import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'padrões: tema escuro, sem aleatório, sem repetir, EQ desligado',
    () async {
      final c = ConfiguracoesService();
      await c.carregar();
      expect(c.temaEscuro, isTrue);
      expect(c.aleatorio, isFalse);
      expect(c.repetir, ModoRepetir.desligado);
      expect(c.eqLigado, isFalse);
      expect(c.eqPreset, 'Normal');
      expect(c.eqGanhos, isEmpty);
    },
  );

  test('persiste tudo entre instâncias', () async {
    final a = ConfiguracoesService();
    await a.carregar();
    await a.definirTemaEscuro(false);
    await a.definirAleatorio(true);
    await a.definirRepetir(ModoRepetir.musica);
    await a.definirEq(ligado: true, preset: 'Rock', ganhos: [5, 2, -2, 2, 5]);

    final b = ConfiguracoesService();
    await b.carregar();
    expect(b.temaEscuro, isFalse);
    expect(b.aleatorio, isTrue);
    expect(b.repetir, ModoRepetir.musica);
    expect(b.eqLigado, isTrue);
    expect(b.eqPreset, 'Rock');
    expect(b.eqGanhos, [5, 2, -2, 2, 5]);
  });

  test('avisa ouvintes ao mudar', () async {
    final c = ConfiguracoesService();
    await c.carregar();
    var avisos = 0;
    c.addListener(() => avisos++);
    await c.definirTemaEscuro(false);
    expect(avisos, 1);
  });

  test('um valor salvo com defeito não apaga os outros', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.luma_tema_escuro': 'quebrado',
      'flutter.luma_repetir': 'musica',
      'flutter.luma_aleatorio': true,
    });
    final c = ConfiguracoesService();
    await c.carregar();
    expect(c.temaEscuro, isTrue);
    expect(c.repetir, ModoRepetir.musica);
    expect(c.aleatorio, isTrue);
  });
}
