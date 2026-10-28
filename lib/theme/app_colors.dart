import 'package:flutter/material.dart';

class AppColors {
  // Tema atual. Trocado pelo ConfiguracoesService (switch na Config).
  static bool escuro = true;

  // Cor principal da Luma (igual nos dois temas)
  static const Color primary = Color(0xFFFF563C);
  // Fundo principal
  static Color get background =>
      escuro ? const Color(0xFF201E1D) : const Color(0xFFF5F3F2);
  // Fundo secundário
  static Color get surface =>
      escuro ? const Color(0xFF252525) : const Color(0xFFFFFFFF);
  // Cinza dos elementos
  static Color get gray =>
      escuro ? const Color(0xFF545454) : const Color(0xFFD9D6D4);
  // Texto principal
  static Color get textPrimary =>
      escuro ? const Color(0xFFF3F2F2) : const Color(0xFF201E1D);
  // Texto secundário
  static Color get textSecondary =>
      escuro ? const Color(0xFFB0AEAD) : const Color(0xFF6B6866);
  // Preto
  static const Color black = Color(0xFF000000);
  // Branco
  static const Color white = Colors.white;
}
