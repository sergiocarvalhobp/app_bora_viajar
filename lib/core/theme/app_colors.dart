import 'package:flutter/material.dart';

/// Paleta "Terra Brasileira" — espelho exato das CSS variables do site.
///
/// Site:
///   --bv-forest:    #1A6B3C   (verde floresta — primário)
///   --bv-forest-dk: #134F2D   (verde escuro)
///   --bv-terra:     #C4622D   (terracota — acento)
///   --bv-terra-lt:  #E07A47   (terracota claro)
///   --bv-sand:      #F5E6D3   (areia — bordas suaves)
///   --bv-cream:     #FAF7F2   (fundo creme)
///   --bv-bark:      #3D2B1F   (casca de árvore — texto escuro)
abstract final class AppColors {
  // ── Verde floresta ────────────────────────────────────────────────────────
  static const forest    = Color(0xFF1A6B3C);
  static const forestDk  = Color(0xFF134F2D);
  static const forestLt  = Color(0xFF2D8A52);  // usado para estados hover/pressed

  // ── Terracota ─────────────────────────────────────────────────────────────
  static const terra     = Color(0xFFC4622D);
  static const terraLt   = Color(0xFFE07A47);

  // ── Neutros quentes ───────────────────────────────────────────────────────
  static const sand      = Color(0xFFF5E6D3);  // bordas, divisores
  static const cream     = Color(0xFFFAF7F2);  // fundo claro
  static const bark      = Color(0xFF3D2B1F);  // texto principal (claro)
  static const barkMuted = Color(0xFF7A6A5A);  // texto secundário

  // ── Escuros (dark mode) ───────────────────────────────────────────────────
  static const darkBg       = Color(0xFF1A1410);  // fundo escuro quente
  static const darkSurface  = Color(0xFF241C17);  // card/superfície escura
  static const darkBorder   = Color(0xFF3D2E25);  // borda no dark
  static const darkText     = Color(0xFFF0E8DF);  // texto claro no dark
  static const darkMuted    = Color(0xFF9C8878);  // texto secundário no dark

  // ── Semânticas ────────────────────────────────────────────────────────────
  static const success = Color(0xFF1A6B3C);   // reutiliza forest
  static const error   = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
  static const info    = Color(0xFF2563EB);
}
