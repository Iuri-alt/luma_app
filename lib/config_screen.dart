import 'package:flutter/material.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:luma_app/widgets/painel_equalizador.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({
    super.key,
    required this.configuracoesService,
    required this.musicaService,
    required this.equalizadorService,
  });

  final ConfiguracoesService configuracoesService;
  final MusicaService musicaService;
  final EqualizadorService equalizadorService;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  // Controla se o EQ está expandido ou não.
  bool _eqExpandido = false;

  // Texto do armazenamento ocupado pelas músicas (null = calculando)
  String? _armazenamento;

  @override
  void initState() {
    super.initState();
    // Recalcula quando a biblioteca termina de ler (ex.: permissão liberada)
    widget.musicaService.addListener(_atualizarArmazenamento);
    _atualizarArmazenamento();
  }

  @override
  void dispose() {
    widget.musicaService.removeListener(_atualizarArmazenamento);
    super.dispose();
  }

  Future<void> _atualizarArmazenamento() async {
    String texto;
    try {
      final musicas = await widget.musicaService.buscarMusicas();
      final total = musicas.fold<int>(0, (soma, m) => soma + m.tamanho);
      final rotulo = musicas.length == 1 ? 'música' : 'músicas';
      texto = '${musicas.length} $rotulo · ${formatarTamanho(total)}';
    } catch (_) {
      texto = 'Indisponível';
    }
    if (mounted) setState(() => _armazenamento = texto);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.configuracoesService,
      builder: (context, _) => _buildTela(),
    );
  }

  Widget _buildTela() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Configurações',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildEqTile(),
                  _divider(),
                  _buildThemeTile(),
                  _divider(),
                  _buildArmazenamentoTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      color: AppColors.background,
    );
  }

  // =========================
  // EQ — expansível (accordion)
  // =========================
  Widget _buildEqTile() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _eqExpandido = !_eqExpandido),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EQ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _eqExpandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_eqExpandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PainelEqualizador(
                  equalizadorService: widget.equalizadorService,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================
  // TEMA — switch Dark/White
  // =========================
  Widget _buildThemeTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tema',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
          Row(
            children: [
              Text(
                widget.configuracoesService.temaEscuro ? 'Escuro' : 'Claro',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Switch(
                value: widget.configuracoesService.temaEscuro,
                activeThumbColor: AppColors.primary,
                onChanged: widget.configuracoesService.definirTemaEscuro,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // ARMAZENAMENTO — total ocupado pelas músicas
  // =========================
  Widget _buildArmazenamentoTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Armazenamento',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
          Text(
            _armazenamento ?? '...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
