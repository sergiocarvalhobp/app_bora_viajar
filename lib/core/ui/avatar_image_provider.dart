import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Resolve um avatar vindo da API:
/// - URL HTTP(S) -> [CachedNetworkImageProvider]
/// - data URL base64 (data:image/...) -> [MemoryImage]
ImageProvider? avatarImageProvider(String? avatar) {
  if (avatar == null || avatar.trim().isEmpty) return null;
  final raw = avatar.trim();

  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma > 0 && comma < raw.length - 1) {
      final b64 = raw.substring(comma + 1);
      try {
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  return CachedNetworkImageProvider(raw);
}
