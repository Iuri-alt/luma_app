import 'package:flutter/material.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/theme/app_colors.dart';

// Liga/desliga, predefinições e uma barra por banda do aparelho
class PainelEqualizador extends StatelessWidget {
  const PainelEqualizador({super.key, required this.equalizadorService});

  final EqualizadorService equalizadorService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: equalizadorService,
      builder: (context, _) {
        final eq = equalizadorService;
        if (!eq.pronto) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Toque uma música para ajustar o equalizador',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLigado(eq),
            const SizedBox(height: 8),
            _buildPresets(eq),
            const SizedBox(height: 16),
            _buildBandas(eq),
          ],
        );
      },
    );
  }

  Widget _buildLigado(EqualizadorService eq) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          eq.ligado ? 'Ligado' : 'Desligado',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        Switch(
          value: eq.ligado,
          activeThumbColor: AppColors.primary,
          onChanged: eq.definirLigado,
        ),
      ],
    );
  }

  // =========================
  // PREDEFINIÇÕES
  // =========================
  Widget _buildPresets(EqualizadorService eq) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final nome in [...presetsEq, 'Personalizado'])
          ChoiceChip(
            label: Text(nome),
            selected: eq.preset == nome,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: eq.preset == nome
                  ? AppColors.white
                  : AppColors.textPrimary,
            ),
            showCheckmark: false,
            onSelected: nome == 'Personalizado'
                ? null
                : (_) => eq.escolherPreset(nome),
          ),
      ],
    );
  }

  // =========================
  // BANDAS (barras verticais)
  // =========================
  Widget _buildBandas(EqualizadorService eq) {
    return Opacity(
      opacity: eq.ligado ? 1 : 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < eq.frequencias.length; i++)
            Column(
              children: [
                Text(
                  _formatarGanho(eq.ganhos[i]),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                SizedBox(
                  height: 160,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.gray,
                        thumbColor: AppColors.primary,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: eq.ganhos[i],
                        min: eq.minimo,
                        max: eq.maximo,
                        onChanged: (valor) =>
                            eq.definirGanho(i, valor, salvar: false),
                        onChangeEnd: (_) => eq.salvarGanhos(),
                      ),
                    ),
                  ),
                ),
                Text(
                  formatarFrequencia(eq.frequencias[i]),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatarGanho(double db) {
    final valor = db.round();
    return '${valor > 0 ? '+' : ''}$valor dB';
  }
}
