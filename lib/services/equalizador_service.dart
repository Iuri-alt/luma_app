import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../functions/luma_functions.dart';
import 'configuracoes_service.dart';

class ParametrosEq {
  const ParametrosEq({
    required this.frequencias,
    required this.minimo,
    required this.maximo,
  });

  final List<double> frequencias;
  final double minimo;
  final double maximo;
}

// Equalizador do aparelho. Separado para os testes usarem um falso.
abstract class EqualizadorNativo {
  Future<ParametrosEq> parametros();
  Future<void> ligar(bool valor);
  Future<void> definirGanho(int banda, double db);
}

class EqualizadorAndroid implements EqualizadorNativo {
  EqualizadorAndroid(this.equalizador);

  final AndroidEqualizer equalizador;
  AndroidEqualizerParameters? _parametros;

  @override
  Future<ParametrosEq> parametros() async {
    final p = _parametros ??= await equalizador.parameters;
    return ParametrosEq(
      frequencias: [for (final b in p.bands) b.centerFrequency],
      minimo: p.minDecibels,
      maximo: p.maxDecibels,
    );
  }

  @override
  Future<void> ligar(bool valor) => equalizador.setEnabled(valor);

  @override
  Future<void> definirGanho(int banda, double db) async {
    final p = _parametros ??= await equalizador.parameters;
    await p.bands[banda].setGain(db);
  }
}

// Estado do EQ mostrado na tela. Só fica pronto depois que uma música
// carrega, porque o Android só cria o equalizador nessa hora.
class EqualizadorService extends ChangeNotifier {
  EqualizadorService({required this.nativo, required this.configuracoes});

  final EqualizadorNativo nativo;
  final ConfiguracoesService configuracoes;

  ParametrosEq? _parametros;
  List<double> _ganhos = [];

  bool get pronto => _parametros != null;
  List<double> get frequencias => _parametros?.frequencias ?? [];
  double get minimo => _parametros?.minimo ?? -15;
  double get maximo => _parametros?.maximo ?? 15;
  List<double> get ganhos => List.unmodifiable(_ganhos);
  bool get ligado => configuracoes.eqLigado;
  String get preset =>
      _personalizado ? 'Personalizado' : configuracoes.eqPreset;
  // Ganho mudado e ainda não salvo (dedo ainda no slider)
  bool _personalizado = false;

  Future<void> preparar() async {
    if (pronto) return;
    final ParametrosEq p;
    try {
      p = await nativo.parametros();
    } catch (_) {
      // Aparelho sem EQ disponível agora; tenta de novo na próxima música
      return;
    }
    final salvos = configuracoes.eqGanhos;
    _parametros = p;
    _ganhos = salvos.length == p.frequencias.length
        ? [for (final g in salvos) g.clamp(p.minimo, p.maximo).toDouble()]
        : ganhosDoPreset(preset, p.frequencias, p.minimo, p.maximo);
    for (var i = 0; i < _ganhos.length; i++) {
      await nativo.definirGanho(i, _ganhos[i]);
    }
    await nativo.ligar(ligado);
    notifyListeners();
  }

  Future<void> definirLigado(bool valor) async {
    await configuracoes.definirEq(ligado: valor);
    if (pronto) await nativo.ligar(valor);
    notifyListeners();
  }

  Future<void> escolherPreset(String nome) async {
    if (!pronto) return;
    _ganhos = ganhosDoPreset(nome, frequencias, minimo, maximo);
    for (var i = 0; i < _ganhos.length; i++) {
      await nativo.definirGanho(i, _ganhos[i]);
    }
    await configuracoes.definirEq(preset: nome, ganhos: _ganhos);
    notifyListeners();
  }

  // Durante o arraste use salvar: false e chame salvarGanhos() ao soltar
  Future<void> definirGanho(int banda, double db, {bool salvar = true}) async {
    if (!pronto) return;
    _ganhos = List.of(_ganhos)..[banda] = db.clamp(minimo, maximo).toDouble();
    _personalizado = true;
    notifyListeners();
    await nativo.definirGanho(banda, _ganhos[banda]);
    if (salvar) await salvarGanhos();
  }

  Future<void> salvarGanhos() async {
    if (!pronto) return;
    _personalizado = false;
    await configuracoes.definirEq(preset: 'Personalizado', ganhos: _ganhos);
  }
}
