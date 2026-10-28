import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class ArmazenamentoService {
  // Instância única compartilhada por todos os services
  static final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> solicitarPermissao() async {
    // Solicitar permissões de armazenamento
    return await _audioQuery.permissionsRequest();
  }

  Future<bool> verificarPermissao() async {
    // Verificar se as permissões já foram concedidas
    return await _audioQuery.permissionsStatus();
  }

  // Android 13+: sem esta permissão a notificação de música não aparece
  Future<void> solicitarNotificacoes() async {
    if (await Permission.notification.isGranted) return;
    await Permission.notification.request();
  }

  OnAudioQuery get audioQuery => _audioQuery;
}
