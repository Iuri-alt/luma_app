import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

enum ModoRepetir { desligado, fila, musica }

// Preferências do usuário: tema, modos do player e EQ
class ConfiguracoesService extends ChangeNotifier {
  static const _chaveTema = 'luma_tema_escuro';
  static const _chaveAleatorio = 'luma_aleatorio';
  static const _chaveRepetir = 'luma_repetir';
  static const _chaveEqLigado = 'luma_eq_ligado';
  static const _chaveEqPreset = 'luma_eq_preset';
  static const _chaveEqGanhos = 'luma_eq_ganhos';

  bool _temaEscuro = true;
  bool _aleatorio = false;
  ModoRepetir _repetir = ModoRepetir.desligado;
  bool _eqLigado = false;
  String _eqPreset = 'Normal';
  List<double> _eqGanhos = [];

  bool get temaEscuro => _temaEscuro;
  bool get aleatorio => _aleatorio;
  ModoRepetir get repetir => _repetir;
  bool get eqLigado => _eqLigado;
  String get eqPreset => _eqPreset;
  List<double> get eqGanhos => List.unmodifiable(_eqGanhos);

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    // Cada chave lida separada: um valor com defeito não derruba as outras
    _temaEscuro = _ler(() => prefs.getBool(_chaveTema), true);
    _aleatorio = _ler(() => prefs.getBool(_chaveAleatorio), false);
    _repetir = _ler(
      () => ModoRepetir.values.firstWhere(
        (m) => m.name == prefs.getString(_chaveRepetir),
        orElse: () => ModoRepetir.desligado,
      ),
      ModoRepetir.desligado,
    );
    _eqLigado = _ler(() => prefs.getBool(_chaveEqLigado), false);
    _eqPreset = _ler(() => prefs.getString(_chaveEqPreset), 'Normal');
    _eqGanhos = _ler(
      () => prefs.getStringList(_chaveEqGanhos)?.map(double.parse).toList(),
      <double>[],
    );
    AppColors.escuro = _temaEscuro;
    notifyListeners();
  }

  T _ler<T>(T? Function() leitura, T padrao) {
    try {
      return leitura() ?? padrao;
    } catch (_) {
      return padrao;
    }
  }

  Future<void> definirTemaEscuro(bool valor) async {
    _temaEscuro = valor;
    AppColors.escuro = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveTema, valor);
  }

  Future<void> definirAleatorio(bool valor) async {
    _aleatorio = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveAleatorio, valor);
  }

  Future<void> definirRepetir(ModoRepetir modo) async {
    _repetir = modo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveRepetir, modo.name);
  }

  Future<void> definirEq({
    bool? ligado,
    String? preset,
    List<double>? ganhos,
  }) async {
    _eqLigado = ligado ?? _eqLigado;
    _eqPreset = preset ?? _eqPreset;
    _eqGanhos = ganhos != null ? List.of(ganhos) : _eqGanhos;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveEqLigado, _eqLigado);
    await prefs.setString(_chaveEqPreset, _eqPreset);
    await prefs.setStringList(
      _chaveEqGanhos,
      _eqGanhos.map((g) => g.toString()).toList(),
    );
  }
}
