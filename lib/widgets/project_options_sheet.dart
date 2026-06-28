import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/palette_colors.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/project_icons.dart';

class ProjectSheetData {
  final String id;
  final String name;
  final Color? color;
  final String? iconName;

  const ProjectSheetData({
    required this.id,
    required this.name,
    this.color,
    this.iconName,
  });
}

enum _SheetPage { menu, name, icon, color }

class ProjectOptionsSheet extends StatefulWidget {
  final ProjectSheetData project;
  final VoidCallback onEdited;
  final VoidCallback onDeleted;

  const ProjectOptionsSheet({
    super.key,
    required this.project,
    required this.onEdited,
    required this.onDeleted,
  });

  @override
  State<ProjectOptionsSheet> createState() => _ProjectOptionsSheetState();
}

class _ProjectOptionsSheetState extends State<ProjectOptionsSheet> {
  _SheetPage _page = _SheetPage.menu;
  late TextEditingController _nameCtrl;
  late Color _selectedColor;
  String? _selectedIcon;
  bool _saving = false;

  static final _colors = PaletteColors.projectColors;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _selectedColor = widget.project.color ?? _colors.first;
    _selectedIcon = widget.project.iconName ?? ProjectIcons.iconList.first.key;
    _nameCtrl.addListener(_onNameChanged);
    _loadProject();
  }

  void _onNameChanged() {
    if (_page == _SheetPage.name && mounted) setState(() {});
  }

  Future<void> _loadProject() async {
    try {
      final row = await supabase
          .from('projects')
          .select('nome, cor, icone')
          .eq('id', widget.project.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _nameCtrl.text = row['nome'] as String? ?? widget.project.name;
        if (row['cor'] != null) {
          _selectedColor = AppColors.parseHex(row['cor'] as String?);
        }
        _selectedIcon = row['icone'] as String? ?? _selectedIcon;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _displayName =>
      _nameCtrl.text.trim().isEmpty ? widget.project.name : _nameCtrl.text.trim();

  Future<bool> _persist() async {
    if (_nameCtrl.text.trim().isEmpty) return false;
    setState(() => _saving = true);
    try {
      final hex =
          '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      try {
        await supabase.from('projects').update({
          'nome': _nameCtrl.text.trim(),
          'cor': hex,
          if (_selectedIcon != null) 'icone': _selectedIcon,
        }).eq('id', widget.project.id);
      } catch (e) {
        if (!e.toString().contains('icone')) rethrow;
        await supabase.from('projects').update({
          'nome': _nameCtrl.text.trim(),
          'cor': hex,
        }).eq('id', widget.project.id);
      }
      widget.onEdited();
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return false;
    }
  }

  Future<void> _saveName() async {
    final ok = await _persist();
    if (ok && mounted) {
      setState(() => _page = _SheetPage.menu);
    }
  }

  Future<void> _pickIcon(String key) async {
    HapticService().selectionClick();
    setState(() => _selectedIcon = key);
    final ok = await _persist();
    if (ok && mounted) setState(() => _page = _SheetPage.menu);
  }

  Future<void> _pickColor(Color color) async {
    HapticService().selectionClick();
    setState(() => _selectedColor = color);
    final ok = await _persist();
    if (ok && mounted) setState(() => _page = _SheetPage.menu);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text(
          'Excluir projeto?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Isso excluirá "$_displayName" e todas as suas tarefas permanentemente.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Excluir',
              style: TextStyle(
                color: AppColors.priorityHigh,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await supabase.from('projects').delete().eq('id', widget.project.id);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDeleted();
    }
  }

  void _goBack() {
    HapticService().selectionClick();
    setState(() => _page = _SheetPage.menu);
  }

  void _openPage(_SheetPage page) {
    HapticService().selectionClick();
    setState(() => _page = page);
  }

  String _pageTitle() {
    switch (_page) {
      case _SheetPage.menu:
        return _displayName;
      case _SheetPage.name:
        return 'Nome';
      case _SheetPage.icon:
        return 'Ícone';
      case _SheetPage.color:
        return 'Cor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                _buildHeader(),
                Flexible(child: _buildPage()),
                SizedBox(
                  height: bottomInset > 0 ? 8 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoBack = _page != _SheetPage.menu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pageTitle(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 20,
              color: AppColors.textTertiary,
            ),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case _SheetPage.menu:
        return _buildMenuPage();
      case _SheetPage.name:
        return _buildNamePage();
      case _SheetPage.icon:
        return _buildIconPage();
      case _SheetPage.color:
        return _buildColorPage();
    }
  }

  Widget _buildMenuPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      border: Border.all(color: _selectedColor, width: 2),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: ProjectIcons.resolve(_selectedIcon),
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toque abaixo para editar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _NavigateRow(
            hugeIcon: HugeIcons.strokeRoundedText,
            label: 'Nome',
            value: _displayName,
            onTap: () => _openPage(_SheetPage.name),
          ),
          Divider(
            height: 1,
            indent: 52,
            color: AppColors.surfaceVariant,
          ),
          _NavigateRow(
            hugeIcon: HugeIcons.strokeRoundedGrid,
            label: 'Ícone',
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedColor.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: ProjectIcons.resolve(_selectedIcon),
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            onTap: () => _openPage(_SheetPage.icon),
          ),
          Divider(
            height: 1,
            indent: 52,
            color: AppColors.surfaceVariant,
          ),
          _NavigateRow(
            hugeIcon: HugeIcons.strokeRoundedPaintBoard,
            label: 'Cor',
            trailing: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
            onTap: () => _openPage(_SheetPage.color),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: AppColors.surfaceVariant,
          ),
          _OptionRow(
            hugeIcon: HugeIcons.strokeRoundedDelete01,
            label: 'Excluir projeto',
            iconColor: AppColors.priorityHigh,
            labelColor: AppColors.priorityHigh,
            onTap: _delete,
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            cursorColor: AppColors.accent,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_saving) _saveName();
            },
            decoration: InputDecoration(
              labelText: 'Nome do projeto',
              labelStyle:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _saving || _nameCtrl.text.trim().isEmpty ? null : _saveName,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _nameCtrl.text.trim().isEmpty
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : Text(
                        'Salvar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.background,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPage() {
    final gridHeight = MediaQuery.of(context).size.height * 0.42;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Escolha um ícone',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: gridHeight,
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: ProjectIcons.iconList.map((entry) {
                final isSelected = _selectedIcon == entry.key;
                return GestureDetector(
                  onTap: _saving ? null : () => _pickIcon(entry.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withValues(alpha: 0.2)
                          : AppColors.surfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : AppColors.textTertiary.withValues(alpha: 0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: entry.value,
                        size: 26,
                        color: isSelected
                            ? _selectedColor
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escolha uma cor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colors.map((c) {
              final isSelected = c.toARGB32() == _selectedColor.toARGB32();
              return GestureDetector(
                onTap: _saving ? null : () => _pickColor(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)]
                        : [],
                  ),
                  child: isSelected
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NavigateRow extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavigateRow({
    required this.hugeIcon,
    required this.label,
    required this.onTap,
    this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            HugeIcon(icon: hugeIcon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (value != null)
              Flexible(
                child: Text(
                  value!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String label;
  final Color iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionRow({
    required this.hugeIcon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            HugeIcon(icon: hugeIcon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: labelColor ?? AppColors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
