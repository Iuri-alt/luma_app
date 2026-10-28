import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/models/musica_model.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/services/player_service.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:luma_app/widgets/painel_equalizador.dart';
import 'package:on_audio_query/on_audio_query.dart'
    show QueryArtworkWidget, ArtworkType;

class ReproducaoScreen extends StatefulWidget {
  const ReproducaoScreen({
    super.key,
    required this.playerService,
    required this.pastaService,
    required this.equalizadorService,
  });

  final PlayerService playerService;
  final PastaService pastaService;
  final EqualizadorService equalizadorService;

  @override
  State<ReproducaoScreen> createState() => _ReproducaoScreenState();
}

class _ReproducaoScreenState extends State<ReproducaoScreen> {
  StreamSubscription<String>? _erros;
  late final Stream<Duration> _posicao = widget.playerService.posicao;
  // Posição enquanto o dedo arrasta o slider (null = não arrastando)
  double? _arrastando;

  @override
  void initState() {
    super.initState();
    _erros = widget.playerService.erros.listen((mensagem) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            mensagem,
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _erros?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.playerService,
            widget.pastaService,
            widget.equalizadorService,
          ]),
          builder: (context, _) {
            final musica = widget.playerService.atual;
            if (musica == null) return _buildSemMusica();
            return Column(
              children: [
                const SizedBox(height: 12),
                _buildCapa(musica),
                _buildInfo(musica),
                _buildProgresso(),
                _buildControles(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSemMusica() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, color: AppColors.textSecondary, size: 64),
          const SizedBox(height: 16),
          Text(
            'Escolha uma música na biblioteca',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // =========================
  // CAPA
  // =========================
  Widget _buildCapa(MusicaModel musica) {
    final semCapa = Icon(Icons.album, color: AppColors.textSecondary, size: 96);
    return Expanded(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface),
        child: QueryArtworkWidget(
          id: musica.id,
          type: ArtworkType.AUDIO,
          artworkBorder: BorderRadius.zero,
          artworkFit: BoxFit.cover,
          artworkWidth: double.infinity,
          artworkHeight: double.infinity,
          size: 1000,
          quality: 100,
          keepOldArtwork: true,
          nullArtworkWidget: semCapa,
          errorBuilder: (_, _, _) => semCapa,
        ),
      ),
    );
  }

  // =========================
  // INFORMAÇÕES DA MÚSICA
  // =========================
  Widget _buildInfo(MusicaModel musica) {
    final favorito = widget.pastaService.ehFavorito(musica.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  musica.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${musica.artista} · ${musica.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _abrirEqualizador,
            icon: Icon(
              Icons.equalizer,
              color: widget.equalizadorService.ligado
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 28,
            ),
          ),

          IconButton(
            onPressed: () => widget.pastaService.alternarFavorito(musica),
            icon: Icon(
              favorito ? Icons.favorite : Icons.favorite_border,
              color: favorito ? AppColors.primary : AppColors.textSecondary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  void _abrirEqualizador() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Equalizador',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              PainelEqualizador(equalizadorService: widget.equalizadorService),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // PROGRESSO
  // =========================
  Widget _buildProgresso() {
    return StreamBuilder<Duration>(
      stream: _posicao,
      builder: (context, snapshot) {
        final total = widget.playerService.duracaoAtual;
        var atual = snapshot.data ?? Duration.zero;
        if (atual > total) atual = total;
        final restante = total - atual;
        final fracao = total.inMilliseconds == 0
            ? 0.0
            : atual.inMilliseconds / total.inMilliseconds;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,

                  inactiveTrackColor: AppColors.gray,

                  thumbColor: AppColors.primary,

                  trackHeight: 3,

                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                ),

                child: Slider(
                  value: (_arrastando ?? fracao).clamp(0.0, 1.0),
                  onChanged: total == Duration.zero
                      ? null
                      : (valor) => setState(() => _arrastando = valor),
                  onChangeEnd: (valor) {
                    setState(() => _arrastando = null);
                    widget.playerService.irPara(total * valor);
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    formatarDuracao(atual),

                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),

                  Text(
                    '-${formatarDuracao(restante)}',

                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // CONTROLES
  // =========================
  Widget _buildControles() {
    final tocando = widget.playerService.tocando;
    final aleatorio = widget.playerService.aleatorio;
    final repetir = widget.playerService.repetir;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          IconButton(
            onPressed: widget.playerService.alternarAleatorio,

            icon: Icon(
              Icons.shuffle,
              color: aleatorio ? AppColors.primary : AppColors.textSecondary,
            ),
          ),

          IconButton(
            onPressed: widget.playerService.anterior,

            icon: Icon(Icons.skip_previous, color: AppColors.textPrimary),
          ),

          // BOTÃO PLAY / PAUSE
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(color: AppColors.primary),

            child: IconButton(
              onPressed: widget.playerService.alternarPlayPause,

              icon: Icon(
                tocando ? Icons.pause : Icons.play_arrow,
                color: AppColors.white,
                size: 28,
              ),
            ),
          ),

          IconButton(
            onPressed: widget.playerService.proxima,

            icon: Icon(Icons.skip_next, color: AppColors.textPrimary),
          ),

          IconButton(
            onPressed: widget.playerService.alternarRepetir,

            icon: Icon(
              repetir == ModoRepetir.musica ? Icons.repeat_one : Icons.repeat,
              color: repetir == ModoRepetir.desligado
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
