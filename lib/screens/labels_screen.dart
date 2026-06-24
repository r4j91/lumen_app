import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';

final _kColors = [
  '#63C7D8', // Ocean Mist
  '#6F8FB8', // Slate Blue
  '#84B98E', // Sage Green
  '#789C6B', // Moss
  '#C58D97', // Dusty Rose
  '#C58A72', // Terracotta Soft
  '#A496C8', // Lavender Grey
  '#6F79B6', // Muted Indigo
  '#C7B38A', // Sand
  '#D3B36A', // Soft Amber
  '#7F99A8', // Steel Blue
  '#9CA3AF', // Mist Grey
];

class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  List<_LabelRow> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final rows = await supabase
          .from('labels')
          .select('id, nome, cor')
          .order('nome') as List;
      if (mounted) {
        setState(() {
          _labels = rows.map((r) => _LabelRow.fromMap(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditor({_LabelRow? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LabelEditorSheet(
        existing: existing,
        onSaved: _loadLabels,
      ),
    );
  }

  Future<void> _deleteLabel(_LabelRow label) async {
    setState(() => _labels.removeWhere((l) => l.id == label.id));

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = messenger.showSnackBar(SnackBar(
      content: Text('"${label.name}" excluída'),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: AppColors.accent,
        onPressed: () {
          undone = true;
          if (mounted) _loadLabels();
        },
      ),
    ));

    await ctrl.closed;
    if (!undone) {
      try {
        await supabase.from('labels').delete().eq('id', label.id);
      } catch (e) {
        if (mounted) {
          _loadLabels();
          messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Gerenciar Etiquetas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.accent),
            onPressed: () => _showEditor(),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : _labels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_outline, size: 52, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text('Nenhuma etiqueta ainda', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Toque em + para criar sua primeira etiqueta.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
                  itemCount: _labels.length,
                  separatorBuilder: (ctx, i) => Divider(height: 1, indent: 56, color: AppColors.surfaceVariant),
                  itemBuilder: (_, i) {
                    final l = _labels[i];
                    final color = AppColors.parseHex(l.color);
                    return ListTile(
                      leading: Icon(Icons.label_outline, size: 22, color: color),
                      title: Text(l.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                            onPressed: () => _showEditor(existing: l),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.priorityHigh),
                            onPressed: () => _deleteLabel(l),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Label editor bottom sheet ─────────────────────────────────────────────────

class _LabelEditorSheet extends StatefulWidget {
  final _LabelRow? existing;
  final VoidCallback onSaved;

  const _LabelEditorSheet({this.existing, required this.onSaved});

  @override
  State<_LabelEditorSheet> createState() => _LabelEditorSheetState();
}

class _LabelEditorSheetState extends State<_LabelEditorSheet> {
  late TextEditingController _nameCtrl;
  String _selectedColor = _kColors.first;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.color ?? _kColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'nome': _nameCtrl.text.trim(),
        'cor': _selectedColor,
      };
      if (_isNew) {
        final userId = supabase.auth.currentUser?.id;
        await supabase.from('labels').insert({
          ...payload,
          if (userId != null) 'user_id': userId,
        });
      } else {
        await supabase.from('labels').update(payload).eq('id', widget.existing!.id);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.priorityHigh),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + mq.padding.bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Preview
          Row(
            children: [
              Icon(Icons.label_outline, size: 20, color: AppColors.parseHex(_selectedColor)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _nameCtrl.text.isEmpty ? 'Nova etiqueta' : _nameCtrl.text,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.parseHex(_selectedColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nome da etiqueta',
              hintText: 'Ex: Importante',
              labelStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Color grid
          Text('Cor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
          const SizedBox(height: 10),
          _ColorGrid(
            selected: _selectedColor,
            onSelected: (c) => setState(() => _selectedColor = c),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                  : Text(_isNew ? 'Criar etiqueta' : 'Salvar', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  const _ColorGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kColors.map((hex) {
        final color = AppColors.parseHex(hex);
        final isSelected = hex == selected;
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
              boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null,
            ),
            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _LabelRow {
  final String id;
  final String name;
  final String color;

  const _LabelRow({required this.id, required this.name, required this.color});

  factory _LabelRow.fromMap(Map r) => _LabelRow(
        id: r['id'].toString(),
        name: r['nome'] as String,
        color: r['cor'] as String? ?? _kColors.first,
      );
}
