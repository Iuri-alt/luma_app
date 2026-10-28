import 'package:flutter/material.dart';
import 'package:luma_app/functions/luma_functions.dart';
import 'package:luma_app/lista_musicas_screen.dart';
import 'package:luma_app/models/album_dispositivo_model.dart';
import 'package:luma_app/models/pasta_model.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/services/player_service.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:luma_app/widgets/capa_widget.dart';
import 'package:luma_app/widgets/dialogo_nome_playlist.dart';
import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({
    super.key,
    required this.musicaService,
    required this.pastaService,
    required this.playerService,
    required this.aoIniciarReproducao,
  });

  final MusicaService musicaService;
  final PastaService pastaService;
  final PlayerService playerService;
  final VoidCallback aoIniciarReproducao;

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _carregando = true;
  bool _permitido = false;
  bool _falhou = false;
  // Já pediu e foi negado (ex.: "não perguntar de novo")
  bool _negadoDeNovo = false;
  List<AlbumDispositivoModel> _albuns = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------
  // AÇÃO: ler álbuns da memória do celular
  // -----------------------------------------------------
  // silencioso: puxar para atualizar (a lista continua na tela enquanto lê)
  Future<void> _carregar({
    bool tentativa = false,
    bool silencioso = false,
  }) async {
    setState(() {
      _carregando = !silencioso;
      _falhou = false;
    });
    widget.musicaService.recarregar();
    try {
      final permitido = await widget.musicaService.garantirPermissao();
      final albuns = permitido
          ? await widget.musicaService.buscarAlbuns()
          : <AlbumDispositivoModel>[];
      if (!mounted) return;
      setState(() {
        _permitido = permitido;
        _negadoDeNovo = tentativa && !permitido;
        _albuns = albuns;
      });
    } catch (_) {
      if (mounted) setState(() => _falhou = true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  bool _combina(String nome) {
    final busca = normalizarTexto(_searchController.text.trim());
    return busca.isEmpty || normalizarTexto(nome).contains(busca);
  }

  void _abrir(Widget tela) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
  }

  void _abrirAlbum(AlbumDispositivoModel album) {
    _abrir(
      ListaMusicasScreen.album(
        album: album,
        musicaService: widget.musicaService,
        pastaService: widget.pastaService,
        playerService: widget.playerService,
        aoIniciarReproducao: widget.aoIniciarReproducao,
      ),
    );
  }

  void _abrirPasta(PastaModel pasta) {
    _abrir(
      ListaMusicasScreen.pasta(
        pastaId: pasta.id,
        musicaService: widget.musicaService,
        pastaService: widget.pastaService,
        playerService: widget.playerService,
        aoIniciarReproducao: widget.aoIniciarReproducao,
      ),
    );
  }

  Future<void> _novaPlaylist() async {
    final nome = await pedirNomePlaylist(context);
    if (nome != null) await widget.pastaService.criar(nome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _carregando
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _falhou
                  ? _buildAviso(
                      icone: Icons.error_outline,
                      texto: 'Não foi possível ler suas músicas',
                      botao: 'Tentar de novo',
                      onPressed: _carregar,
                    )
                  : !_permitido
                  ? _buildAviso(
                      icone: Icons.folder_off,
                      texto: 'O Luma precisa de acesso às suas músicas',
                      detalhe: _negadoDeNovo
                          ? 'Se o pedido não aparecer, libere em Configurações '
                                '> Apps > Luma > Permissões > Música e áudio.'
                          : null,
                      botao: 'Permitir acesso',
                      onPressed: () => _carregar(tentativa: true),
                    )
                  : ListenableBuilder(
                      listenable: widget.pastaService,
                      builder: (context, _) => _buildConteudo(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    final favoritos = widget.pastaService.favoritos;
    final playlists = widget.pastaService.playlists
        .where((p) => _combina(p.nome))
        .toList();
    final albuns = agruparPorLetra(
      _albuns.where((a) => _combina(a.nome)).toList(),
      (a) => a.nome,
    );
    final mostrarFavoritos = _combina(favoritos.nome);
    final vazio = !mostrarFavoritos && playlists.isEmpty && albuns.isEmpty;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _carregar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildNovaPlaylistButton(),
          const SizedBox(height: 20),

          if (vazio)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nada encontrado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

          if (mostrarFavoritos) ...[
            _buildSectionLabel('Favoritos'),
            _buildTile(
              titulo: favoritos.nome,
              quantidade: favoritos.musicas.length,
              capa: _iconeCapa(Icons.favorite, AppColors.primary),
              onTap: () => _abrirPasta(favoritos),
            ),
          ],

          if (playlists.isNotEmpty) ...[
            _buildSectionLabel('Playlists'),
            for (final p in playlists)
              _buildTile(
                titulo: p.nome,
                quantidade: p.musicas.length,
                capa: _iconeCapa(Icons.queue_music, AppColors.textSecondary),
                onTap: () => _abrirPasta(p),
                onMenu: () => _abrirMenuPlaylist(p),
              ),
          ],

          for (final letra in albuns.keys) ...[
            _buildSectionLabel(letra),
            for (final a in albuns[letra]!)
              _buildTile(
                titulo: a.nome,
                quantidade: a.quantidadeMusicas,
                capa: CapaWidget(id: a.id, tipo: ArtworkType.ALBUM),
                onTap: () => _abrirAlbum(a),
              ),
          ],
        ],
      ),
    );
  }

  // =========================
  // AVISO (sem permissão ou erro)
  // =========================
  Widget _buildAviso({
    required IconData icone,
    required String texto,
    String? detalhe,
    required String botao,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            if (detalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                detalhe,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: Text(botao),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // BARRA SUPERIOR
  // =========================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'BIBLIOTECA',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  // =========================
  // CAMPO DE BUSCA
  // =========================
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buscar',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // =========================
  // BOTÃO "NOVA PLAYLIST"
  // =========================
  Widget _buildNovaPlaylistButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _novaPlaylist,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Nova playlist',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // LABEL DE SEÇÃO (Favoritos, A, K...)
  // =========================
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: label.length == 1
            ? Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _iconeCapa(IconData icone, Color cor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        color: AppColors.gray,
        child: Icon(icone, color: cor),
      ),
    );
  }

  // =========================
  // ITEM DE ÁLBUM/PLAYLIST
  // =========================
  Widget _buildTile({
    required String titulo,
    required int quantidade,
    required Widget capa,
    required VoidCallback onTap,
    VoidCallback? onMenu,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            capa,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$quantidade ${quantidade == 1 ? 'música' : 'músicas'}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onMenu != null)
              IconButton(
                onPressed: onMenu,
                icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  // =========================
  // MENU DA PLAYLIST (renomear, excluir)
  // =========================
  Future<void> _abrirMenuPlaylist(PastaModel pasta) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.textSecondary),
              title: Text(
                'Renomear',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, 'renomear'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.textSecondary),
              title: Text(
                'Excluir',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, 'excluir'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (escolha == 'renomear') {
      final nome = await pedirNomePlaylist(
        context,
        titulo: 'Renomear playlist',
        acao: 'Salvar',
        inicial: pasta.nome,
      );
      if (nome != null) await widget.pastaService.renomear(pasta.id, nome);
    } else if (escolha == 'excluir') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Excluir playlist?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            '"${pasta.nome}" será apagada. As músicas continuam no celular.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Excluir',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
      if (confirmar == true) await widget.pastaService.excluir(pasta.id);
    }
  }
}
