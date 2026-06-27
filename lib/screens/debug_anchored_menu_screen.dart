import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/anchored_select_menu.dart';
import 'package:hugeicons/hugeicons.dart';

class DebugAnchoredMenuScreen extends StatefulWidget {
  const DebugAnchoredMenuScreen({super.key});

  @override
  State<DebugAnchoredMenuScreen> createState() =>
      _DebugAnchoredMenuScreenState();
}

class _DebugAnchoredMenuScreenState extends State<DebugAnchoredMenuScreen> {
  final _priorityKey = GlobalKey();
  final _labelsKey = GlobalKey();
  final _projectKey = GlobalKey();
  final _longKey = GlobalKey();
  final _bottomKey = GlobalKey();

  String? _priority;
  final Set<String> _labels = {};
  String? _project;
  String? _longPicked;
  String? _bottomPicked;

  static const _priorityItems = [
    AnchoredMenuItem(
        id: 'p1',
        label: 'Prioridade 1',
        icon: Icons.flag,
        iconColor: Color(0xFFDC4C3E),
        selected: false),
    AnchoredMenuItem(
        id: 'p2',
        label: 'Prioridade 2',
        icon: Icons.flag,
        iconColor: Color(0xFFEB8909),
        selected: false),
    AnchoredMenuItem(
        id: 'p3',
        label: 'Prioridade 3',
        icon: Icons.flag,
        iconColor: Color(0xFF246FE0),
        selected: false),
    AnchoredMenuItem(
        id: 'p4',
        label: 'Sem prioridade',
        icon: Icons.flag_outlined,
        iconColor: Color(0xFF6B6E76),
        selected: false),
  ];

  static const _labelItems = [
    AnchoredMenuItem(id: 'work', label: 'Trabalho', icon: Icons.circle, iconColor: Color(0xFF14AAF5)),
    AnchoredMenuItem(id: 'personal', label: 'Pessoal', icon: Icons.circle, iconColor: Color(0xFF299438)),
    AnchoredMenuItem(id: 'idea', label: 'Ideia', icon: Icons.circle, iconColor: Color(0xFFAF38EB)),
    AnchoredMenuItem(id: 'urgent', label: 'Urgente', icon: Icons.circle, iconColor: Color(0xFFDB4035)),
  ];

  static const _projectItems = [
    AnchoredMenuItem(id: 'inbox', label: 'Caixa de entrada', icon: Icons.move_to_inbox_rounded),
    AnchoredMenuItem(id: 'proj1', label: 'Design System', icon: Icons.circle, iconColor: Color(0xFF5FD3DC)),
    AnchoredMenuItem(id: 'proj2', label: 'Stacked App', icon: Icons.circle, iconColor: Color(0xFFB18CF5)),
    AnchoredMenuItem(id: 'proj3', label: 'Pessoal', icon: Icons.circle, iconColor: Color(0xFF8FD46B)),
  ];

  Future<void> _showPriority() async {
    final items = _priorityItems
        .map((e) => AnchoredMenuItem(
              id: e.id,
              label: e.label,
              icon: e.icon,
              iconColor: e.iconColor,
              selected: e.id == _priority,
            ))
        .toList();
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _priorityKey,
      items: items,
      menuWidth: 200,
    );
    if (result != null) setState(() => _priority = result);
  }

  Future<void> _showLabels() async {
    // Multi-select demo: open menu repeatedly to toggle
    final items = _labelItems
        .map((e) => AnchoredMenuItem(
              id: e.id,
              label: e.label,
              icon: e.icon,
              iconColor: e.iconColor,
              selected: _labels.contains(e.id),
            ))
        .toList();
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _labelsKey,
      items: items,
    );
    if (result != null) {
      setState(() {
        if (_labels.contains(result)) {
          _labels.remove(result);
        } else {
          _labels.add(result);
        }
      });
    }
  }

  Future<void> _showProject() async {
    final items = _projectItems
        .map((e) => AnchoredMenuItem(
              id: e.id,
              label: e.label,
              icon: e.icon,
              iconColor: e.iconColor,
              selected: e.id == _project,
            ))
        .toList();
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _projectKey,
      items: items,
      menuWidth: 240,
    );
    if (result != null) setState(() => _project = result);
  }

  Future<void> _showLong() async {
    final longItems = List.generate(
      12,
      (i) => AnchoredMenuItem(
        id: 'item$i',
        label: 'Opção ${i + 1}',
        selected: _longPicked == 'item$i',
      ),
    );
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _longKey,
      items: longItems,
      menuWidth: 200,
    );
    if (result != null) setState(() => _longPicked = result);
  }

  Future<void> _showBottom() async {
    final items = _priorityItems
        .map((e) => AnchoredMenuItem(
              id: e.id,
              label: e.label,
              icon: e.icon,
              iconColor: e.iconColor,
              selected: e.id == _bottomPicked,
            ))
        .toList();
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _bottomKey,
      items: items,
    );
    if (result != null) setState(() => _bottomPicked = result);
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
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Teste: AnchoredSelectMenu',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _SectionLabel('Abrir menus — âncora normal'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                key: _priorityKey,
                label: _priority == null
                    ? 'Prioridade'
                    : _priorityItems
                        .firstWhere((e) => e.id == _priority)
                        .label,
                icon: Icons.flag_outlined,
                active: _priority != null,
                onTap: _showPriority,
              ),
              _Chip(
                key: _labelsKey,
                label: _labels.isEmpty
                    ? 'Etiquetas'
                    : 'Etiquetas (${_labels.length})',
                icon: Icons.label_outline,
                active: _labels.isNotEmpty,
                onTap: _showLabels,
              ),
              _Chip(
                key: _projectKey,
                label: _project == null
                    ? 'Projeto'
                    : _projectItems
                        .firstWhere((e) => e.id == _project)
                        .label,
                icon: Icons.grid_view_rounded,
                active: _project != null,
                onTap: _showProject,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionLabel('Lista longa (scroll interno, max 320px)'),
          const SizedBox(height: 12),
          _Chip(
            key: _longKey,
            label: _longPicked == null ? 'Lista longa (12 itens)' : 'Selecionado: $_longPicked',
            icon: Icons.list_rounded,
            active: _longPicked != null,
            onTap: _showLong,
          ),
          const SizedBox(height: 32),
          _SectionLabel('Descrição do comportamento'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.flip_outlined, text: 'Flip automático: se não cabe abaixo, abre acima do chip'),
          _InfoRow(icon: Icons.touch_app_outlined, text: 'Fecha ao tocar fora, pressionar Esc ou selecionar'),
          _InfoRow(icon: Icons.animation_outlined, text: 'Scale+fade 150ms, origem no canto do menu'),
          _InfoRow(icon: Icons.highlight_alt_outlined, text: 'Linha inteira iluminada no item selecionado (não só checkmark)'),
          _InfoRow(icon: Icons.devices_outlined, text: 'Mesmo componente em mobile e desktop'),
          const SizedBox(height: 40),
          _SectionLabel('Flip (âncora perto do fim da tela)'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _Chip(
              key: _bottomKey,
              label: _bottomPicked == null ? 'Abre acima ↑' : _priorityItems.firstWhere((e) => e.id == _bottomPicked).label,
              icon: Icons.keyboard_arrow_up_rounded,
              active: _bottomPicked != null,
              onTap: _showBottom,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este chip está no final da tela — o menu deve abrir acima (flip automático).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Local helpers ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.textTertiary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
