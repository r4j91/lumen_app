import 'package:flutter/material.dart';
import '../services/app_icon_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_colors.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  final _service = AppIconService();

  AppIconOption? _current;
  bool _supported = false;
  String _loadingId = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      _service.isSupported,
      _service.getCurrentIcon(),
    ]);
    if (!mounted) return;
    setState(() {
      _supported = results[0] as bool;
      _current = results[1] as AppIconOption;
      _initialized = true;
    });
  }

  Future<void> _select(AppIconOption option) async {
    if (_loadingId != '' || option.id == _current?.id) return;
    HapticService().selectionClick();

    setState(() => _loadingId = option.id);

    final ok = await _service.changeIcon(option);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _current = option;
        _loadingId = '';
      });
    } else {
      setState(() => _loadingId = '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível alterar o ícone'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ícone do app', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_supported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                ),
                child: Icon(Icons.block_rounded, size: 34, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 20),
              Text(
                'Não suportado',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A troca de ícone não é suportada neste dispositivo ou plataforma.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final icons = _service.getAvailableIcons();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Active icon preview
        _ActiveIconPreview(current: _current),
        const SizedBox(height: 28),

        // Label
        Text(
          'Escolha um ícone',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: icons.length,
          itemBuilder: (_, i) => _IconCard(
            option: icons[i],
            selected: _current?.id == icons[i].id,
            loading: _loadingId == icons[i].id,
            onTap: () => _select(icons[i]),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          'A troca de ícone é aplicada imediatamente. No Android, o app pode piscar brevemente ao alterar.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Active icon preview ───────────────────────────────────────────────────────

class _ActiveIconPreview extends StatelessWidget {
  final AppIconOption? current;
  const _ActiveIconPreview({required this.current});

  @override
  Widget build(BuildContext context) {
    if (current == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(current!.id),
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                current!.assetPath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            current!.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ícone ativo',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Icon card ─────────────────────────────────────────────────────────────────

class _IconCard extends StatelessWidget {
  final AppIconOption option;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _IconCard({
    required this.option,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : AppColors.surfaceVariant,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    : Image.asset(
                        option.assetPath,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.check_circle_rounded, size: 12, color: AppColors.accent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
