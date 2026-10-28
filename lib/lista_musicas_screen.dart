import 'package:flutter/material.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/models/musica_model.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/services/player_service.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:luma_app/widgets/capa_widget.dart';
import 'package:luma_app/widgets/dialogo_nome_playlist.dart';
import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

// Lista de músicas de um álbum do aparelho ou de uma playlist
class ListaMusicasScreen extends StatefulWidget {
  const ListaMusicasScreen.album({
    super.key,
    required AlbumDispositivoModel this.album,
    required this.musicaService,
    required this.pastaService,
    required this.playerService,
    required this.aoIniciarReproducao,
  }) : pastaId = null;

  const ListaMusicasScreen.pasta({
    super.key,
    required String this.pastaId,
    required this.musicaService,
    required this.pastaService,
    required this.playerService,
    required this.aoIniciarReproducao,
  }) : album = null;

  final AlbumDispositivoModel? album;
  final String? pastaId;
  final MusicaService musicaService;
  final PastaService pastaService;
  final PlayerService playerService;
  final VoidCallback aoIniciarReproducao;

  @override
  State<ListaMusicasScreen> createState() => _ListaMusicasScreenState();
}

class _ListaMusicasScreenState extends State<ListaMusicasScreen> {
  List<MusicaModel>? _todas;

  bool get _ehPasta => widget.pastaId != null;

  @override
  void initState() {
    super.initState();
    widget.musicaService
        .buscarMusicas()
        .catchError((Object _) => <MusicaModel>[])
        .then((todas) {
          if (mounted) setState(() => _todas = todas);
        });
  }

  // Músicas visíveis agora, na ordem da tela
  List<MusicaModel> _musicasVisiveis(List<MusicaModel> todas) {
    final album = widget.album;
    if (album != null) {
      return widget.musicaService.musicasDoAlbum(todas, album.id);
    }

    final pasta = widget.pastaService.pasta(widget.pastaId!);
    if (pasta == null) return [];
    final resultado = resolverMusicas(pasta.musicas, todas);
    // Ids mudaram no aparelho: salva os novos depois do build
    final mudou = [
      for (var i = 0; i < pasta.musicas.length; i++)
        pasta.musicas[i].id != resultado.refsAtualizadas[i].id,
    ].any((d) => d);
    if (mudou) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.pastaService.atualizarRefs(pasta.id, resultado.refsAtualizadas);
      });
    }
    return resultado.encontradas;
  }

  String get _titulo {
    final album = widget.album;
    if (album != null) return album.nome;
    return widget.pastaService.pasta(widget.pastaId!)?.nome ?? '';
  }

  Future<void> _tocar(List<MusicaModel> lista, int indice) async {
    await widget.playerService.tocarFila(lista, indice);
    if (!mounted) return;
    Navigator.maybePop(context);
    widget.aoIniciarReproducao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.pastaService,
          builder: (context, _) {
            final todas = _todas;
            return Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: todas == null
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _buildLista(_musicasVisiveis(todas)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================
  // BARRA SUPERIOR
  // =========================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // LISTA DE MÚSICAS
  // =========================
  Widget _buildLista(List<MusicaModel> musicas) {
    if (musicas.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma música ainda',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: musicas.length,
      itemBuilder: (context, i) => _buildMusicaTile(musicas, i),
    );
  }

  Widget _buildMusicaTile(List<MusicaModel> musicas, int i) {
    final musica = musicas[i];
    return InkWell(
      onTap: () => _tocar(musicas, i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            CapaWidget(
              id: musica.id,
              tipo: ArtworkType.AUDIO,
              tamanho: 44,
              icone: Icons.music_note,
            ),
            const SizedBox(width: 12),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${musica.artista} · '
                    '${formatarDuracao(Duration(milliseconds: musica.duracao))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.pastaService.ehFavorito(musica.id))
              Icon(Icons.favorite, color: AppColors.primary, size: 16),
            IconButton(
              onPressed: () => _abrirMenu(musica),
              icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // MENU DA MÚSICA
  // =========================
  Future<void> _abrirMenu(MusicaModel musica) async {
    final favorito = widget.pastaService.ehFavorito(musica.id);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcao(
              context,
              Icons.playlist_add,
              'Adicionar à playlist',
              'adicionar',
            ),
            _opcao(
              context,
              favorito ? Icons.favorite : Icons.favorite_border,
              favorito ? 'Desfavoritar' : 'Favoritar',
              'favoritar',
            ),
            if (_ehPasta)
              _opcao(
                context,
                Icons.remove_circle_outline,
                'Remover da playlist',
                'remover',
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    switch (escolha) {
      case 'adicionar':
        await _adicionarAPlaylist(musica);
      case 'favoritar':
        await widget.pastaService.alternarFavorito(musica);
      case 'remover':
        await widget.pastaService.removerMusica(widget.pastaId!, musica.id);
    }
  }

  Future<void> _adicionarAPlaylist(MusicaModel musica) async {
    final playlists = widget.pastaService.playlists
        .where((p) => p.id != widget.pastaId)
        .toList();
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _opcao(context, Icons.add, 'Nova playlist', ''),
            for (final p in playlists)
              _opcao(context, Icons.queue_music, p.nome, p.id),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    var pastaId = escolha;
    if (pastaId.isEmpty) {
      final nome = await pedirNomePlaylist(context);
      if (nome == null) return;
      pastaId = (await widget.pastaService.criar(nome)).id;
    }
    await widget.pastaService.adicionarMusica(pastaId, musica);
  }

  Widget _opcao(
    BuildContext context,
    IconData icone,
    String texto,
    String valor,
  ) {
    return ListTile(
      leading: Icon(icone, color: AppColors.textSecondary),
      title: Text(texto, style: TextStyle(color: AppColors.textPrimary)),
      onTap: () => Navigator.pop(context, valor),
    );
  }
}
