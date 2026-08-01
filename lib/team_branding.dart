import 'package:flutter/material.dart';

/// Central visual identity for every team shown in the tracker.
///
/// The registry understands both the client-facing prediction names and the
/// canonical OpenDota names. A live-feed logo takes precedence; the branded
/// monogram is the final fallback.
class TeamBrand {
  const TeamBrand({
    required this.canonicalName,
    required this.displayName,
    required this.code,
    required this.primary,
    required this.secondary,
    required this.aliases,
  });

  final String canonicalName;
  final String displayName;
  final String code;
  final Color primary;
  final Color secondary;
  final Set<String> aliases;

  bool matches(String value) {
    final key = normalizeTeamKey(value);
    return aliases.any((alias) => normalizeTeamKey(alias) == key) ||
        normalizeTeamKey(canonicalName) == key ||
        normalizeTeamKey(displayName) == key;
  }
}

const teamBrands = <TeamBrand>[
  TeamBrand(
    canonicalName: 'PARIVISION',
    displayName: 'TEAM VISION',
    code: 'TV',
    primary: Color(0xFF38BDF8),
    secondary: Color(0xFF0F172A),
    aliases: {'PARIVISION', 'Parivision', 'TEAM VISION'},
  ),
  TeamBrand(
    canonicalName: 'Team Yandex',
    displayName: 'TEAM YANDEX',
    code: 'TY',
    primary: Color(0xFFFFCC00),
    secondary: Color(0xFF141414),
    aliases: {'Team Yandex', 'TEAM YANDEX', 'Yandex'},
  ),
  TeamBrand(
    canonicalName: 'BetBoom Team',
    displayName: 'BOOMBOYS',
    code: 'BB',
    primary: Color(0xFFFFC400),
    secondary: Color(0xFF121212),
    aliases: {'BetBoom Team', 'BetBoom', 'BB Team', 'BOOMBOYS'},
  ),
  TeamBrand(
    canonicalName: 'Team Falcons',
    displayName: 'TEAM FALCONS',
    code: 'TF',
    primary: Color(0xFF22C55E),
    secondary: Color(0xFF052E16),
    aliases: {'Team Falcons', 'Falcons', 'TEAM FALCONS'},
  ),
  TeamBrand(
    canonicalName: 'Team Spirit',
    displayName: 'TEAM SPIRIT',
    code: 'TS',
    primary: Color(0xFFB8C0CC),
    secondary: Color(0xFF1F2937),
    aliases: {'Team Spirit', 'Spirit', 'TEAM SPIRIT'},
  ),
  TeamBrand(
    canonicalName: 'Nigma Galaxy',
    displayName: 'NIGMA GALAXY',
    code: 'NG',
    primary: Color(0xFF5B8CFF),
    secondary: Color(0xFF0B1636),
    aliases: {'Nigma Galaxy', 'Nigma', 'NIGMA GALAXY'},
  ),
  TeamBrand(
    canonicalName: 'Vici Gaming',
    displayName: 'VICI GAMING',
    code: 'VG',
    primary: Color(0xFFE5484D),
    secondary: Color(0xFF2D1114),
    aliases: {'Vici Gaming', 'Vici', 'VG', 'VICI GAMING'},
  ),
  TeamBrand(
    canonicalName: 'Aurora Gaming',
    displayName: 'AURORA GAMING',
    code: 'AU',
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFF20143B),
    aliases: {'Aurora Gaming', 'Aurora', 'AURORA GAMING'},
  ),
  TeamBrand(
    canonicalName: 'Team Liquid',
    displayName: 'TEAM LIQUID',
    code: 'TL',
    primary: Color(0xFF4F9CF9),
    secondary: Color(0xFF0B1A31),
    aliases: {'Team Liquid', 'Liquid', 'TEAM LIQUID'},
  ),
  TeamBrand(
    canonicalName: 'LGD Gaming',
    displayName: 'LGD GAMING',
    code: 'LGD',
    primary: Color(0xFFE5484D),
    secondary: Color(0xFF182B5F),
    aliases: {'LGD Gaming', 'LGD', 'LGD GAMING', 'PSG.LGD'},
  ),
  TeamBrand(
    canonicalName: 'IRON WING',
    displayName: 'IRON WING',
    code: 'IW',
    primary: Color(0xFF94A3B8),
    secondary: Color(0xFF111827),
    aliases: {'IRON WING', 'Iron Wing', '1win', '1win Team'},
  ),
  TeamBrand(
    canonicalName: 'Xtreme Gaming',
    displayName: 'XTREME GAMING',
    code: 'XG',
    primary: Color(0xFFF97316),
    secondary: Color(0xFF341409),
    aliases: {'Xtreme Gaming', 'Xtreme', 'XG', 'XTREME GAMING'},
  ),
  TeamBrand(
    canonicalName: 'OG',
    displayName: 'OG',
    code: 'OG',
    primary: Color(0xFFE11D48),
    secondary: Color(0xFF2A0B13),
    aliases: {'OG'},
  ),
  TeamBrand(
    canonicalName: 'GamerLegion',
    displayName: 'GAMERLEGION',
    code: 'GL',
    primary: Color(0xFFEF4444),
    secondary: Color(0xFF2B1010),
    aliases: {'GamerLegion', 'GAMERLEGION'},
  ),
  TeamBrand(
    canonicalName: 'Team Resilience',
    displayName: 'TEAM RESILIENCE',
    code: 'TR',
    primary: Color(0xFF14B8A6),
    secondary: Color(0xFF042F2E),
    aliases: {'Team Resilience', 'Resilience', 'TEAM RESILIENCE'},
  ),
  TeamBrand(
    canonicalName: 'HULIGANI',
    displayName: 'HULIGANI',
    code: 'HU',
    primary: Color(0xFFA855F7),
    secondary: Color(0xFF2E1065),
    aliases: {'HULIGANI', 'Huligani', 'L1ga Team', 'L1GA TEAM', 'L1 Team'},
  ),
];

TeamBrand teamBrandFor(String name, {String? alternateName}) {
  for (final brand in teamBrands) {
    if (brand.matches(name) ||
        (alternateName != null && brand.matches(alternateName))) {
      return brand;
    }
  }

  final words = name.trim().split(RegExp(r'\s+'));
  final fallbackName = words.first.isEmpty ? 'TM' : words.first;
  final codeLength = fallbackName.length < 2 ? fallbackName.length : 2;
  final code = words.length == 1
      ? fallbackName.substring(0, codeLength).toUpperCase()
      : words.take(2).map((word) => word[0]).join().toUpperCase();

  return TeamBrand(
    canonicalName: name,
    displayName: name.toUpperCase(),
    code: code,
    primary: const Color(0xFFD8A84E),
    secondary: const Color(0xFF171B22),
    aliases: {name},
  );
}

String normalizeTeamKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Real logo first; brand-aware monogram only when the URL is missing/fails.
class TeamLogo extends StatelessWidget {
  const TeamLogo({
    super.key,
    required this.name,
    this.alternateName,
    this.logoUrl,
    this.size = 48,
    this.showGlow = true,
  });

  final String name;
  final String? alternateName;
  final String? logoUrl;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final brand = teamBrandFor(name, alternateName: alternateName);
    final resolvedUrl = _cleanUrl(logoUrl);
    final radius = size * 0.28;
    final fallback = _BrandMonogram(brand: brand, size: size);

    return Semantics(
      label: '${brand.displayName} logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.10),
        decoration: BoxDecoration(
          color: brand.secondary.withAlpha(220),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: brand.primary.withAlpha(120)),
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: brand.primary.withAlpha(34),
                    blurRadius: size * 0.42,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: resolvedUrl == null
            ? fallback
            : Image.network(
                resolvedUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                frameBuilder: (context, child, frame, synchronous) {
                  if (synchronous || frame != null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.25,
                      height: size * 0.25,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.7,
                        color: brand.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class TeamAccentCard extends StatelessWidget {
  const TeamAccentCard({
    super.key,
    required this.name,
    required this.child,
    this.alternateName,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  final String name;
  final String? alternateName;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brand = teamBrandFor(name, alternateName: alternateName);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: brand.primary.withAlpha(80)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primary.withAlpha(18), const Color(0xFF11141A)],
        ),
      ),
      child: child,
    );
  }
}

class TeamStatusChip extends StatelessWidget {
  const TeamStatusChip({
    super.key,
    required this.name,
    required this.label,
    this.alternateName,
  });

  final String name;
  final String? alternateName;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = teamBrandFor(name, alternateName: alternateName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: brand.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brand.primary.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: brand.primary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _BrandMonogram extends StatelessWidget {
  const _BrandMonogram({required this.brand, required this.size});

  final TeamBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primary.withAlpha(78), brand.secondary],
        ),
      ),
      child: Text(
        brand.code,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.27,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.25,
        ),
      ),
    );
  }
}

String? _cleanUrl(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
