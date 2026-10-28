import 'dart:math' as math;

import '../models/album_dispositivo_model.dart';
import '../models/musica_model.dart';
import '../models/pasta_model.dart';

String formatarDuracao(Duration duracao) {
  final minutos = duracao.inMinutes;
  final segundos = duracao.inSeconds % 60;
  final doisDigitosMinutos = minutos.toString().padLeft(2, '0');
  final doisDigitosSegundos = segundos.toString().padLeft(2, '0');
  return '$doisDigitosMinutos:$doisDigitosSegundos';
}

const _acentos = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'ê': 'e',
  'è': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

// Minúsculas e sem acentos, para busca e ordenação
String normalizarTexto(String texto) {
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    buffer.write(_acentos[letra] ?? letra);
  }
  return buffer.toString();
}

// Agrupa pela primeira letra (sem acento). Número/símbolo vai em '#', por último.
Map<String, List<T>> agruparPorLetra<T>(
  List<T> itens,
  String Function(T) nome,
) {
  final grupos = <String, List<T>>{};
  for (final item in itens) {
    final normalizado = normalizarTexto(nome(item).trim());
    final primeira = normalizado.isEmpty ? '' : normalizado[0].toUpperCase();
    final chave = RegExp(r'^[A-Z]$').hasMatch(primeira) ? primeira : '#';
    grupos.putIfAbsent(chave, () => []).add(item);
  }
  for (final lista in grupos.values) {
    lista.sort(
      (a, b) => normalizarTexto(nome(a)).compareTo(normalizarTexto(nome(b))),
    );
  }
  final chaves = grupos.keys.toList()
    ..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
  return {for (final c in chaves) c: grupos[c]!};
}

// Reencontra as músicas salvas no aparelho: pelo id, senão pelos metadados.
// Refs não encontradas continuam salvas, mas não aparecem.
({List<MusicaModel> encontradas, List<MusicaRef> refsAtualizadas})
resolverMusicas(List<MusicaRef> refs, List<MusicaModel> doAparelho) {
  final porId = {for (final m in doAparelho) m.id: m};
  final encontradas = <MusicaModel>[];
  final refsAtualizadas = <MusicaRef>[];
  for (final ref in refs) {
    var musica = porId[ref.id];
    if (musica == null) {
      for (final m in doAparelho) {
        if (m.titulo == ref.titulo &&
            m.artista == ref.artista &&
            m.duracao == ref.duracao) {
          musica = m;
          break;
        }
      }
    }
    if (musica == null) {
      refsAtualizadas.add(ref);
    } else {
      encontradas.add(musica);
      refsAtualizadas.add(MusicaRef.deMusica(musica));
    }
  }
  return (encontradas: encontradas, refsAtualizadas: refsAtualizadas);
}

// Recalcula a quantidade de cada álbum só com músicas (sem toques/áudios)
// e tira os álbuns que ficaram vazios
List<AlbumDispositivoModel> ajustarContagemAlbuns(
  List<AlbumDispositivoModel> albuns,
  List<MusicaModel> musicas,
) {
  final contagem = <int, int>{};
  for (final m in musicas) {
    final id = m.albumId;
    if (id != null) contagem[id] = (contagem[id] ?? 0) + 1;
  }
  return [
    for (final a in albuns)
      if ((contagem[a.id] ?? 0) > 0)
        AlbumDispositivoModel(
          id: a.id,
          nome: a.nome,
          artista: a.artista,
          quantidadeMusicas: contagem[a.id]!,
        ),
  ];
}

// Tamanho em bytes para texto curto (vírgula decimal)
String formatarTamanho(int bytes) {
  const unidades = ['KB', 'MB', 'GB'];
  if (bytes < 1024) return '$bytes B';
  var valor = bytes / 1024;
  var i = 0;
  while (valor >= 1024 && i < unidades.length - 1) {
    valor /= 1024;
    i++;
  }
  return '${valor.toStringAsFixed(1).replaceAll('.', ',')} ${unidades[i]}';
}

// =========================
// EQ — predefinições
// =========================
// Curvas em dB nas frequências de referência (Hz). Bandas de outros
// aparelhos recebem o valor interpolado na escala logarítmica.
const _frequenciasReferencia = [60.0, 230.0, 910.0, 3600.0, 14000.0];
const _curvasEq = {
  'Normal': [0.0, 0.0, 0.0, 0.0, 0.0],
  'Grave': [6.0, 4.0, 0.0, 0.0, 0.0],
  'Agudo': [0.0, 0.0, 0.0, 4.0, 6.0],
  'Vocal': [-2.0, 0.0, 4.0, 3.0, 0.0],
  'Rock': [5.0, 2.0, -2.0, 2.0, 5.0],
  'Pop': [-1.0, 2.0, 4.0, 2.0, -1.0],
};
final presetsEq = _curvasEq.keys.toList();

List<double> ganhosDoPreset(
  String preset,
  List<double> frequencias,
  double minimo,
  double maximo,
) {
  final curva = _curvasEq[preset] ?? _curvasEq['Normal']!;
  final logRef = _frequenciasReferencia.map(math.log).toList();
  double valorEm(double frequencia) {
    final x = math.log(frequencia);
    if (x <= logRef.first) return curva.first;
    if (x >= logRef.last) return curva.last;
    for (var i = 0; i < logRef.length - 1; i++) {
      if (x <= logRef[i + 1]) {
        final t = (x - logRef[i]) / (logRef[i + 1] - logRef[i]);
        return curva[i] + (curva[i + 1] - curva[i]) * t;
      }
    }
    return curva.last;
  }

  return [
    for (final f in frequencias) valorEm(f).clamp(minimo, maximo).toDouble(),
  ];
}

// 60 -> '60 Hz', 3600 -> '3,6 kHz', 14000 -> '14 kHz'
String formatarFrequencia(double hz) {
  if (hz < 1000) return '${hz.round()} Hz';
  final khz = hz / 1000;
  final texto = khz == khz.roundToDouble()
      ? khz.round().toString()
      : khz.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto kHz';
}
