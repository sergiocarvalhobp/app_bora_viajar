import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'avatar_image_provider.dart';

/// Avatar com fallback seguro (404 / rede não derruba a tela).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.foto,
    this.name,
    this.initials,
    this.radius = 22,
    this.backgroundColor,
    this.textColor,
    this.localFile,
  });

  final String? foto;
  final String? name;
  final String? initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  /// Foto escolhida localmente (ex.: antes de salvar o perfil).
  final File? localFile;

  String get _initials {
    if (initials != null && initials!.trim().isNotEmpty) {
      return initials!.trim();
    }
    final n = name?.trim() ?? '';
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.sand;
    final fg = textColor ?? AppColors.bark;
    final size = radius * 2;

    if (localFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: FileImage(localFile!),
      );
    }

    final raw = foto?.trim();
    if (raw != null && raw.startsWith('data:image')) {
      final provider = avatarImageProvider(raw);
      if (provider != null) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          backgroundImage: provider,
        );
      }
    }

    final url = resolveAvatarUrl(foto);
    if (url == null) {
      return _initialsCircle(radius, bg, fg);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 200),
          errorWidget: (_, __, ___) => _InitialsFallback(
            initials: _initials,
            size: size,
            backgroundColor: bg,
            textColor: fg,
          ),
          placeholder: (_, __) => _InitialsFallback(
            initials: _initials,
            size: size,
            backgroundColor: bg,
            textColor: fg,
          ),
        ),
      ),
    );
  }

  Widget _initialsCircle(double radius, Color bg, Color fg) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.initials,
    required this.size,
    required this.backgroundColor,
    required this.textColor,
  });

  final String initials;
  final double size;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: size * 0.28,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
