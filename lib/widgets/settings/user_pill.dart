import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'header_liquid_pill.dart';

class UserPill extends StatelessWidget {
  final String email;
  final String apelido;
  final String nome;
  final String? avatarPath;

  const UserPill({
    super.key,
    required this.email,
    this.apelido = '',
    this.nome = '',
    this.avatarPath,
  });

  String get _initials {
    final display =
        apelido.isNotEmpty ? apelido : nome.isNotEmpty ? nome : email.split('@').first;
    final parts = display.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return display.substring(0, display.length.clamp(0, 2)).toUpperCase();
  }

  String get _displayName {
    if (apelido.isNotEmpty) return apelido;
    if (nome.isNotEmpty) return nome.split(' ').first;
    final local = email.split('@').first;
    return local
        .split('.')
        .map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  bool get _hasPhoto => avatarPath != null && avatarPath!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return HeaderLiquidPill(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.18),
              image: _hasPhoto
                  ? DecorationImage(image: NetworkImage(avatarPath!), fit: BoxFit.cover)
                  : null,
            ),
            child: _hasPhoto
                ? null
                : Center(
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
