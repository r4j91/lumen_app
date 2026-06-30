import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import 'header_liquid_pill.dart';

class UserPill extends StatelessWidget {
  final String email;
  final String apelido;
  final String nome;
  final String? avatarPath;
  final bool showName;

  const UserPill({
    super.key,
    required this.email,
    this.apelido = '',
    this.nome = '',
    this.avatarPath,
    this.showName = true,
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
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: showName ? null : AppLayout.headerControlSize,
        height: showName ? null : AppLayout.headerControlSize,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showName ? 12 : 0,
            vertical: showName ? 8 : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: showName ? 28 : AppLayout.headerAvatarSize,
                height: showName ? 28 : AppLayout.headerAvatarSize,
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
                        fontSize: showName ? 13 : 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
          ),
          if (showName) ...[
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
        ],
          ),
        ),
      ),
    );
  }
}
