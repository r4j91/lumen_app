import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/project_icons.dart';

// Dados mínimos de projeto necessários para o sheet
class ProjectSheetData {
  final String id;
  final String name;
  const ProjectSheetData({required this.id, required this.name});
}

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
  bool _editMode = false;
  late TextEditingController _nameCtrl;
  late Color _selectedColor;
  bool _saving = false;

  // ICONS-OLD: sem seleção de ícone — só cor. Persistido em _saveEdits
  // com fallback (coluna 'icone' pode ainda não existir no banco).
  String? _selectedIcon;

  // PROJECT-ICONS-OLD: lista de (icon: Icons.x, name: 'y') Material —
  // movido pra ProjectIcons.iconList (lib/utils/project_icons.dart),
  // mesmas strings salvas no Supabase, agora resolvendo pra Hugeicons.

  // COLORS-OLD: 12 cores — mantidas todas, +8 novas abaixo. (O pedido
  // sugeriu records (name, hex), mas _colors aqui é List<Color> simples,
  // usado direto por _selectedColor/_saveEdits; mantido o formato real.)
  static const _colors = [
    Color(0xFF63C7D8), // Ocean Mist
    Color(0xFF6F8FB8), // Slate Blue
    Color(0xFF84B98E), // Sage Green
    Color(0xFF789C6B), // Moss
    Color(0xFFC58D97), // Dusty Rose
    Color(0xFFC58A72), // Terracotta Soft
    Color(0xFFA496C8), // Lavender Grey
    Color(0xFF6F79B6), // Muted Indigo
    Color(0xFFC7B38A), // Sand
    Color(0xFFD3B36A), // Soft Amber
    Color(0xFF7F99A8), // Steel Blue
    Color(0xFF9CA3AF), // Mist Grey
    Color(0xFFF43F5E), // Rose
    Color(0xFFEC4899), // Pink
    Color(0xFFD946EF), // Fuchsia
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFF84CC16), // Lime
    Color(0xFFF59E0B), // Amber
    Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _selectedColor = _colors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final hex = '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      // ICON-SAVE-OLD: update sem 'icone' — coluna não existia no banco.
      // Tenta com 'icone'; se a coluna não existir (ainda não migrada),
      // cai no update sem ela (mesmo padrão de fallback usado em
      // project_detail_screen.dart para colunas opcionais).
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
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onEdited();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Excluir projeto?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'Isso excluirá "${widget.project.name}" e todas as suas tarefas permanentemente.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Excluir', style: TextStyle(color: AppColors.priorityHigh, fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    // LINK-STYLE-OLD: Container raiz sem Material/DefaultTextStyle local —
    // a rota (ModalSheetRoute) também não fornece um Material próprio.
    // return Container(
    //   decoration: BoxDecoration(
    //     color: AppColors.surface,
    //     borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    //   ),
    //   padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 8 : 24),
    //   child: Column(
    //     mainAxisSize: MainAxisSize.min,
    //     children: [ ... ],
    //   ),
    // );
    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 8 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.project.name,
                    // LINK-STYLE-OLD: sem decoration: TextDecoration.none explícito.
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
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 20, color: AppColors.textTertiary),
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                ),
              ],
            ),
          ),
          if (!_editMode) ...[
            _OptionRow(
              icon: Icons.edit_outlined,
              label: 'Editar nome e cor',
              iconColor: AppColors.accent,
              onTap: () => setState(() => _editMode = true),
            ),
            Divider(height: 1, indent: 52, color: AppColors.surfaceVariant),
            _OptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Excluir projeto',
              iconColor: AppColors.priorityHigh,
              labelColor: AppColors.priorityHigh,
              onTap: _delete,
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  labelText: 'Nome do projeto',
                  labelStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            // ICONS-OLD: grid de ícones não existia — só o bloco de cor abaixo.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ícone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  // PROJECT-ICONS-V1: grid com HugeIcon
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: ProjectIcons.iconList.map((entry) {
                      final isSelected = _selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = entry.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? _selectedColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _selectedColor : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          // PROJECT-SIZE-OLD: size: 22
                          child: Center(
                            child: HugeIcon(
                              icon: entry.value,
                              // PROJECT-SIZE-V1
                              size: 28,
                              color: isSelected ? _selectedColor : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _colors.map((c) {
                      final isSelected = c == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : [],
                          ),
                          child: isSelected ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: GestureDetector(
                onTap: _saving ? null : _saveEdits,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _nameCtrl.text.trim().isEmpty
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _saving
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                        : Text('Salvar alterações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.background)),
                  ),
                ),
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

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
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
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            // LINK-STYLE-OLD: sem decoration: TextDecoration.none explícito.
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
