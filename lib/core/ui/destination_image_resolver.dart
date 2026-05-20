import 'package:flutter/foundation.dart';

/// Imagem local genérica quando o destino não casa com nenhuma keyword.
const String defaultDestinationAsset =
    'assets/images/destinations/nordeste.webp';

/// Resolve uma imagem local de destino com base em texto livre.
///
/// Usa score por palavras-chave para escolher o asset mais parecido.
/// Se não houver match, retorna [defaultDestinationAsset].
String resolveDestinationAsset({
  required String destino,
  String? estado,
  String? cidade,
  String? atrativo,
}) {
  final source = _normalize([destino, estado, cidade, atrativo]
      .whereType<String>()
      .join(' '));

  if (source.isEmpty) return defaultDestinationAsset;

  String? bestAsset;
  var bestScore = 0;

  for (final entry in _assetKeywords.entries) {
    var score = 0;
    for (final keyword in entry.value) {
      final k = _normalize(keyword);
      if (k.isEmpty) continue;
      if (source.contains(k)) {
        // Frases mais longas valem mais.
        score += 2 + k.split(' ').length;
      }
    }

    // Pequeno boost se o nome do arquivo também bate.
    final filenameToken = entry.key
        .split('/')
        .last
        .split('.')
        .first
        .replaceAll('_', ' ');
    if (source.contains(_normalize(filenameToken))) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestAsset = entry.key;
    }
  }

  if (kDebugMode && bestAsset != null) {
    debugPrint('[DestinoImagem] "$destino" -> $bestAsset (score=$bestScore)');
  }

  return bestScore > 0 ? bestAsset! : defaultDestinationAsset;
}

String _normalize(String input) {
  final lower = input.toLowerCase().trim();
  if (lower.isEmpty) return '';
  return lower
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');
}

const Map<String, List<String>> _assetKeywords = {
  'assets/images/destinations/rio.jpg': [
    'rio',
    'rio de janeiro',
    'copacabana',
    'ipanema',
    'cristo redentor',
    'rj',
  ],
  'assets/images/destinations/sao_paulo.jpg': [
    'sao paulo',
    'sp',
    'paulista',
    'avenida paulista',
  ],
  'assets/images/destinations/florianopolis.webp': [
    'florianopolis',
    'floripa',
    'sc',
  ],
  'assets/images/destinations/gramado.jpg': [
    'gramado',
    'canela',
    'serra gaucha',
  ],
  'assets/images/destinations/bonito.jpg': [
    'bonito',
    'mato grosso do sul',
    'ms',
  ],
  'assets/images/destinations/noronha.jpg': [
    'fernando de noronha',
    'noronha',
    'pe',
  ],
  'assets/images/destinations/chapada_veadeiros.jpg': [
    'chapada dos veadeiros',
    'veadeiros',
    'alto paraiso',
    'sao jorge',
    'goias',
    'go',
  ],
  'assets/images/destinations/chapada.webp': [
    'chapada',
    'chapada diamantina',
    'diamantina',
  ],
  'assets/images/destinations/ouro_preto.jpg': [
    'ouro preto',
    'mg',
    'minas',
  ],
  'assets/images/destinations/pantanal.jpg': [
    'pantanal',
    'mt',
    'mato grosso',
  ],
  'assets/images/destinations/iguacu.jpg': [
    'foz do iguacu',
    'iguacu',
    'cataratas',
    'pr',
  ],
  'assets/images/destinations/salvador_pelourinho.jpg': [
    'salvador',
    'pelourinho',
    'bahia',
    'ba',
  ],
  'assets/images/destinations/jalapao.jpg': [
    'jalapao',
    'to',
    'tocantins',
  ],
  'assets/images/destinations/amazonia.jpg': [
    'amazonia',
    'amazonia',
    'manaus',
    'am',
  ],
  'assets/images/destinations/lencois.jpg': [
    'lencois',
    'lencois maranhenses',
    'barreirinhas',
    'ma',
    'maranhao',
  ],
  'assets/images/destinations/nordeste.webp': [
    'nordeste',
    'fortaleza',
    'natal',
    'joao pessoa',
    'maceio',
    'recife',
    'aracaju',
  ],
};
