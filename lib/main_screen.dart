import 'package:flutter/material.dart';
import 'package:luma_app/biblioteca_screen.dart';
import 'package:luma_app/reproducao_screen.dart';
import 'package:luma_app/config_screen.dart';
import 'package:luma_app/theme/app_colors.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/services/player_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.musicaService,
    required this.pastaService,
    required this.playerService,
    required this.configuracoesService,
    required this.equalizadorService,
  });

  final MusicaService musicaService;
  final PastaService pastaService;
  final PlayerService playerService;
  final ConfiguracoesService configuracoesService;
  final EqualizadorService equalizadorService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    BibliotecaScreen(
      musicaService: widget.musicaService,
      pastaService: widget.pastaService,
      playerService: widget.playerService,
      aoIniciarReproducao: () => setState(() => _currentIndex = 1),
    ),
    ReproducaoScreen(
      playerService: widget.playerService,
      pastaService: widget.pastaService,
      equalizadorService: widget.equalizadorService,
    ),
    ConfigScreen(
      configuracoesService: widget.configuracoesService,
      musicaService: widget.musicaService,
      equalizadorService: widget.equalizadorService,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: IndexedStack(index: _currentIndex, children: _screens),

      bottomNavigationBar: Container(
        height: 52,

        decoration: BoxDecoration(color: AppColors.surface),

        child: Row(
          children: [
            Expanded(
              child: _bottomItem(Icons.library_music, _currentIndex == 0, () {
                setState(() {
                  _currentIndex = 0;
                });
              }),
            ),

            Expanded(
              child: _bottomItem(Icons.music_note, _currentIndex == 1, () {
                setState(() {
                  _currentIndex = 1;
                });
              }),
            ),

            Expanded(
              child: _bottomItem(Icons.settings, _currentIndex == 2, () {
                setState(() {
                  _currentIndex = 2;
                });
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
        ),

        child: Icon(
          icon,
          color: selected ? AppColors.black : AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}
