import 'package:flutter/material.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:on_audio_query/on_audio_query.dart';

// Capa vinda do aparelho, com ícone quando não houver
class CapaWidget extends StatelessWidget {
  const CapaWidget({
    super.key,
    required this.id,
    required this.tipo,
    this.tamanho = 52,
    this.icone = Icons.album,
  });

  final int id;
  final ArtworkType tipo;
  final double tamanho;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final semCapa = Container(
      width: tamanho,
      height: tamanho,
      color: AppColors.gray,
      child: Icon(icone, color: AppColors.textSecondary, size: tamanho * 0.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: QueryArtworkWidget(
          id: id,
          type: tipo,
          artworkWidth: tamanho,
          artworkHeight: tamanho,
          artworkBorder: BorderRadius.zero,
          artworkFit: BoxFit.cover,
          size: (tamanho * 3).round().clamp(100, 1000),
          keepOldArtwork: true,
          nullArtworkWidget: semCapa,
          errorBuilder: (_, _, _) => semCapa,
        ),
      ),
    );
  }
}
