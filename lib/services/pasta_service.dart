import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/musica_model.dart';
import '../models/pasta_model.dart';

// Guarda Favoritos e playlists do usuário no aparelho
class PastaService extends ChangeNotifier {
  static const chave = 'luma_pastas_v1';
  static const _chaveBackup = 'luma_pastas_v1_backup';
  static const idFavoritos = 'favoritos';

  List<PastaModel> _pastas = [];

  PastaModel get favoritos => _pastas.firstWhere((p) => p.ehFavoritos);

  List<PastaModel> get playlists =>
      List.unmodifiable(_pastas.where((p) => !p.ehFavoritos));

  PastaModel? pasta(String id) {
    for (final p in _pastas) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.get(chave);
    var pastas = <PastaModel>[];

    if (bruto != null) {
      try {
        pastas = (jsonDecode(bruto as String) as List<dynamic>)
            .map((p) => PastaModel.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Dados inválidos: guarda o original e começa do zero
        await prefs.setString(_chaveBackup, bruto.toString());
        pastas = [];
      }
    }

    if (!pastas.any((p) => p.ehFavoritos)) {
      pastas.insert(
        0,
        PastaModel(
          id: idFavoritos,
          nome: 'Favoritos',
          musicas: [],
          ehFavoritos: true,
        ),
      );
    }

    _pastas = pastas;
    notifyListeners();
  }

  Future<PastaModel> criar(String nome) async {
    final limpo = _validarNome(nome);
    final nova = PastaModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nome: limpo,
      musicas: [],
      ehFavoritos: false,
    );
    _pastas = [..._pastas, nova];
    await _salvar();
    return nova;
  }

  Future<void> renomear(String id, String nome) async {
    _protegerFavoritos(id);
    final limpo = _validarNome(nome);
    await _alterar(id, (p) => p.copyWith(nome: limpo));
  }

  Future<void> excluir(String id) async {
    _protegerFavoritos(id);
    _pastas = _pastas.where((p) => p.id != id).toList();
    await _salvar();
  }

  Future<void> adicionarMusica(String pastaId, MusicaModel musica) async {
    final alvo = pasta(pastaId);
    if (alvo == null || alvo.musicas.any((m) => m.id == musica.id)) return;
    await _alterar(
      pastaId,
      (p) => p.copyWith(musicas: [...p.musicas, MusicaRef.deMusica(musica)]),
    );
  }

  Future<void> removerMusica(String pastaId, int musicaId) async {
    await _alterar(
      pastaId,
      (p) => p.copyWith(
        musicas: p.musicas.where((m) => m.id != musicaId).toList(),
      ),
    );
  }

  bool ehFavorito(int musicaId) =>
      favoritos.musicas.any((m) => m.id == musicaId);

  Future<void> alternarFavorito(MusicaModel musica) async {
    if (ehFavorito(musica.id)) {
      await removerMusica(idFavoritos, musica.id);
    } else {
      await adicionarMusica(idFavoritos, musica);
    }
  }

  // Usado depois de resolverMusicas; só salva se algum id mudou
  Future<void> atualizarRefs(String pastaId, List<MusicaRef> refs) async {
    final alvo = pasta(pastaId);
    if (alvo == null) return;
    final mudou =
        alvo.musicas.length != refs.length ||
        [for (var i = 0; i < refs.length; i++) alvo.musicas[i].id != refs[i].id]
            .any((d) => d);
    if (!mudou) return;
    await _alterar(pastaId, (p) => p.copyWith(musicas: refs));
  }

  String _validarNome(String nome) {
    final limpo = nome.trim();
    if (limpo.isEmpty) {
      throw ArgumentError('Nome da playlist não pode ser vazio');
    }
    return limpo;
  }

  void _protegerFavoritos(String id) {
    if (id == idFavoritos) {
      throw ArgumentError('Favoritos não pode ser alterado');
    }
  }

  Future<void> _alterar(
    String id,
    PastaModel Function(PastaModel) mudanca,
  ) async {
    _pastas = [
      for (final p in _pastas)
        if (p.id == id) mudanca(p) else p,
    ];
    await _salvar();
  }

  Future<void> _salvar() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      chave,
      jsonEncode(_pastas.map((p) => p.toJson()).toList()),
    );
  }
}
