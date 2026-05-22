import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../app_env.dart';

/// Converte caminho relativo da API (`/manus-storage/...`) em URL absoluta.
String? resolveAvatarUrl(String? avatar) {
  if (avatar == null || avatar.trim().isEmpty) return null;
  final raw = avatar.trim();

  if (raw.startsWith('data:image') ||
      raw.startsWith('http://') ||
      raw.startsWith('https://')) {
    return raw;
  }

  final base = AppEnv.effectiveApiBaseUrl;
  if (raw.startsWith('/')) {
    return '$base$raw';
  }
  return '$base/$raw';
}

/// Resolve um avatar vindo da API:
/// - URL HTTP(S) ou caminho `/manus-storage/...` -> [CachedNetworkImageProvider]
/// - data URL base64 (data:image/...) -> [MemoryImage]
ImageProvider? avatarImageProvider(String? avatar) {
  final resolved = resolveAvatarUrl(avatar);
  if (resolved == null) return null;

  if (resolved.startsWith('data:image')) {
    final comma = resolved.indexOf(',');
    if (comma > 0 && comma < resolved.length - 1) {
      final b64 = resolved.substring(comma + 1);
      try {
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  return CachedNetworkImageProvider(resolved);
}
