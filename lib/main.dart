import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:luma_app/main_screen.dart';
import 'package:luma_app/services/configuracoes_service.dart';
import 'package:luma_app/services/equalizador_service.dart';
import 'package:luma_app/services/musica_service.dart';
import 'package:luma_app/services/pasta_service.dart';
import 'package:luma_app/services/player_service.dart';
import 'package:luma_app/splash_screen.dart';
import 'package:luma_app/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Notificação e controles na tela bloqueada
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.luma.player.audio',
    androidNotificationChannelName: 'Reprodução',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notificacao',
  );
  final configuracoesService = ConfiguracoesService();
  final pastaService = PastaService();
  await Future.wait([configuracoesService.carregar(), pastaService.carregar()]);
  final equalizador = AndroidEqualizer();
  final equalizadorService = EqualizadorService(
    nativo: EqualizadorAndroid(equalizador),
    configuracoes: configuracoesService,
  );
  runApp(
    MyApp(
      musicaService: MusicaService(),
      pastaService: pastaService,
      playerService: PlayerService(
        configuracoes: configuracoesService,
        criarPlayer: () => AudioPlayer(
          audioPipeline: AudioPipeline(androidAudioEffects: [equalizador]),
        ),
        aoPrepararAudio: equalizadorService.preparar,
      ),
      configuracoesService: configuracoesService,
      equalizadorService: equalizadorService,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _temaEscuro = widget.configuracoesService.temaEscuro;

  @override
  void initState() {
    super.initState();
    widget.configuracoesService.addListener(_aoMudarConfig);
  }

  @override
  void dispose() {
    widget.configuracoesService.removeListener(_aoMudarConfig);
    super.dispose();
  }

  // As cores vêm de AppColors (estático), então ao trocar o tema todos os
  // widgets precisam redesenhar, inclusive os const, sem perder o estado.
  void _aoMudarConfig() {
    if (widget.configuracoesService.temaEscuro == _temaEscuro) return;
    _temaEscuro = widget.configuracoesService.temaEscuro;
    void redesenhar(Element elemento) {
      elemento.markNeedsBuild();
      elemento.visitChildren(redesenhar);
    }

    (context as Element).visitChildren(redesenhar);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luma',
      theme: ThemeData(
        brightness: _temaEscuro ? Brightness.dark : Brightness.light,
        // Lido de AppColors a cada troca de tema (menus de baixo abertos também)
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surface,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: _temaEscuro ? Brightness.dark : Brightness.light,
        ),
      ),
      // Ícones da barra de status e navegação seguem o tema do app, não o do sistema
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (_temaEscuro
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppColors.background,
                ),
        child: child!,
      ),
      home: SplashScreen(
        proximaTela: (_) => MainScreen(
          musicaService: widget.musicaService,
          pastaService: widget.pastaService,
          playerService: widget.playerService,
          configuracoesService: widget.configuracoesService,
          equalizadorService: widget.equalizadorService,
        ),
      ),
    );
  }
}
