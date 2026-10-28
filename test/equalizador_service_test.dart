import 'package:flutter_test/flutter_test.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late ConfiguracoesService config;
  late NativoFalso nativo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    config = ConfiguracoesService();
    await config.carregar();
    nativo = NativoFalso();
  });

  test('antes de preparar não tem bandas', () {
    final eq = EqualizadorService(nativo: nativo, configuracoes: config);
    expect(eq.pronto, isFalse);
  });

  test('preparar lê bandas e aplica o que estava salvo', () async {
    await config.definirEq(
      ligado: true,
      preset: 'Rock',
      ganhos: [5, 2, -2, 2, 5],
    );
    final eq = EqualizadorService(nativo: nativo, configuracoes: config);
    await eq.preparar();
    await eq.preparar();
    expect(nativo.pedidosDeParametros, 1);
    expect(eq.pronto, isTrue);
    expect(eq.frequencias, [60, 230, 910, 3600, 14000]);
    expect(nativo.ligado, isTrue);
    expect(nativo.ganhos[0], 5);
    expect(nativo.ganhos[2], -2);
  });

  test('escolher preset aplica curva e salva', () async {
    final eq = EqualizadorService(nativo: nativo, configuracoes: config);
    await eq.preparar();
    await eq.escolherPreset('Grave');
    expect(eq.preset, 'Grave');
    expect(eq.ganhos.first, 6);
    expect(nativo.ganhos[0], 6);
    expect(config.eqPreset, 'Grave');
    expect(config.eqGanhos.first, 6);
  });

  test('mexer numa banda vira Personalizado', () async {
    final eq = EqualizadorService(nativo: nativo, configuracoes: config);
    await eq.preparar();
    await eq.definirGanho(3, 7);
    expect(eq.preset, 'Personalizado');
    expect(nativo.ganhos[3], 7);
    expect(config.eqGanhos[3], 7);
  });

  test('ligar e desligar vai para o nativo e salva', () async {
    final eq = EqualizadorService(nativo: nativo, configuracoes: config);
    await eq.preparar();
    await eq.definirLigado(true);
    expect(nativo.ligado, isTrue);
    expect(config.eqLigado, isTrue);
  });
}
