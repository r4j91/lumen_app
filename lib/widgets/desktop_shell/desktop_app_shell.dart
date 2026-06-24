import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'desktop_sidebar.dart';
import 'desktop_top_bar.dart';
import 'desktop_content_area.dart';
import '../../theme/app_colors.dart';
import '../../screens/appearance_screen.dart';
import '../../screens/logbook_screen.dart';
import '../../screens/labels_screen.dart';

class DesktopAppShell extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onNewTask;
  final VoidCallback? onSearch;
  final VoidCallback? onProjectCreated;

  const DesktopAppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onNewTask,
    this.onSearch,
    this.onProjectCreated,
  });

  @override
  State<DesktopAppShell> createState() => _DesktopAppShellState();
}

class _DesktopAppShellState extends State<DesktopAppShell> {
  // Título de cada aba (índice 0-4)
  static const _sectionTitles = [
    'Projetos',
    'Inbox',
    'Hoje',
    'Em breve',
    'Filtros',
  ];

  String get _sectionTitle {
    final i = widget.selectedIndex;
    return (i >= 0 && i < _sectionTitles.length) ? _sectionTitles[i] : '';
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    final metaOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final shifted = HardwareKeyboard.instance.isShiftPressed;
    final textFocused = _isTextFieldFocused();

    // Esc → fecha modal/sheet mais recente
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return true;
    }

    // Cmd/Ctrl+K → busca
    if (metaOrCtrl && key == LogicalKeyboardKey.keyK) {
      widget.onSearch?.call();
      return true;
    }

    // Q → nova tarefa (sem texto em foco)
    if (!metaOrCtrl && !shifted && key == LogicalKeyboardKey.keyQ && !textFocused) {
      widget.onNewTask?.call();
      return true;
    }

    // ? (Shift+/) → painel de atalhos
    if (!metaOrCtrl && shifted && key == LogicalKeyboardKey.slash && !textFocused) {
      _showShortcutsDialog();
      return true;
    }

    // Cmd/Ctrl+1..5 → navegar entre abas
    if (metaOrCtrl) {
      final tabKey = {
        LogicalKeyboardKey.digit1: 0,
        LogicalKeyboardKey.digit2: 1,
        LogicalKeyboardKey.digit3: 2,
        LogicalKeyboardKey.digit4: 3,
        LogicalKeyboardKey.digit5: 4,
      }[key];
      if (tabKey != null) {
        widget.onDestinationSelected(tabKey);
        return true;
      }
    }

    return false;
  }

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(48),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 480,
            child: const AppearanceScreen(),
          ),
        ),
      ),
    );
  }

  void _openLogbook() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: AppColors.background,
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
            child: const LogbookScreen(),
          ),
        ),
      ),
    );
  }

  void _openLabelFilter(String labelId, String labelName) {
    // Navega para a tela de etiquetas mostrando todas (roteamento completo
    // com filtro por label será implementado quando go_router for integrado)
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: AppColors.background,
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: const LabelsScreen(),
          ),
        ),
      ),
    );
  }

  void _showShortcutsDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _ShortcutsPanel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────────────
            DesktopSidebar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              onSettings: _openSettings,
              onNewTask: widget.onNewTask,
              onLogbookTap: _openLogbook,
              onLabelTap: (id, name) => _openLabelFilter(id, name),
            ),
            // ── Vertical divider ─────────────────────────────────────────────
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.surfaceVariant,
            ),
            // ── Main column: TopBar + Content ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DesktopTopBar(
                    onSearch: widget.onSearch,
                    title: _sectionTitle,
                  ),
                  Expanded(
                    child: DesktopContentArea(child: widget.body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painel de atalhos de teclado ──────────────────────────────────────────────

class _ShortcutsPanel extends StatelessWidget {
  static const _shortcuts = [
    ('Navegação', [
      ('Q', 'Nova tarefa'),
      ('⌘K', 'Busca rápida'),
      ('⌘1 – ⌘5', 'Ir para aba (Projetos → Filtros)'),
      ('Esc', 'Fechar modal / sheet'),
      ('? (Shift+/)', 'Esta tela de atalhos'),
    ]),
    ('Dialog de tarefa', [
      ('⌘⏎', 'Salvar tarefa'),
      ('Esc', 'Cancelar / fechar'),
    ]),
  ];

  const _ShortcutsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.surfaceVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Atalhos de teclado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            // Sections
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _shortcuts.map((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...section.$2.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            _KbdBadge(item.$1),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KbdBadge extends StatelessWidget {
  final String label;
  const _KbdBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
