import 'package:flutter/material.dart';
import 'package:luma_app/theme/app_colors.dart';

// Pede o nome de uma playlist. Devolve null se cancelar.
// O botão de confirmar fica desabilitado enquanto o nome estiver vazio.
Future<String?> pedirNomePlaylist(
  BuildContext context, {
  String titulo = 'Nova playlist',
  String acao = 'Criar',
  String inicial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _DialogoNomePlaylist(titulo: titulo, acao: acao, inicial: inicial),
  );
}

class _DialogoNomePlaylist extends StatefulWidget {
  const _DialogoNomePlaylist({
    required this.titulo,
    required this.acao,
    required this.inicial,
  });

  final String titulo;
  final String acao;
  final String inicial;

  @override
  State<_DialogoNomePlaylist> createState() => _DialogoNomePlaylistState();
}

class _DialogoNomePlaylistState extends State<_DialogoNomePlaylist> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.inicial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nome = _controller.text.trim();
    if (nome.isNotEmpty) Navigator.pop(context, nome);
  }

  @override
  Widget build(BuildContext context) {
    final valido = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.titulo,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Nome da playlist',
          hintStyle: TextStyle(color: AppColors.textSecondary),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirmar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: valido ? _confirmar : null,
          child: Text(
            widget.acao,
            style: TextStyle(
              color: valido ? AppColors.primary : AppColors.gray,
            ),
          ),
        ),
      ],
    );
  }
}
