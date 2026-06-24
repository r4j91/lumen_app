import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/subtask_repository.dart';
import '../theme/app_colors.dart';

/// Abre o gerador de parcelas (N subtarefas com vencimentos calculados
/// automaticamente) para a tarefa [taskId].
Future<void> showInstallmentGeneratorSheet(
  BuildContext context, {
  required String taskId,
  required String taskTitle,
  required VoidCallback onGenerated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InstallmentGeneratorSheet(
      taskId: taskId,
      taskTitle: taskTitle,
      onGenerated: onGenerated,
    ),
  );
}

class InstallmentGeneratorSheet extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final VoidCallback onGenerated;

  const InstallmentGeneratorSheet({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.onGenerated,
  });

  @override
  State<InstallmentGeneratorSheet> createState() => _InstallmentGeneratorSheetState();
}

class _InstallmentGeneratorSheetState extends State<InstallmentGeneratorSheet> {
  static const _repo = SubtaskRepository();
  static const _kMonths = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  late final TextEditingController _nameCtrl;
  final _valorCtrl = TextEditingController();

  int _quantity = 12;
  DateTime _firstDueDate = DateTime.now();
  String _frequency = 'monthly'; // 'monthly' | 'biweekly' | 'weekly'
  bool _generating = false;

  double? get _valor => double.tryParse(_valorCtrl.text.replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.taskTitle);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  // ── Cálculo de datas ──────────────────────────────────────────────────────

  List<DateTime> _generateDates() {
    return List.generate(_quantity, (i) {
      switch (_frequency) {
        case 'biweekly':
          return _firstDueDate.add(Duration(days: i * 14));
        case 'weekly':
          return _firstDueDate.add(Duration(days: i * 7));
        case 'monthly':
        default:
          final totalMonths = _firstDueDate.month - 1 + i;
          final year = _firstDueDate.year + totalMonths ~/ 12;
          final month = totalMonths % 12 + 1;
          final lastDayOfMonth = DateTime(year, month + 1, 0).day;
          final day = _firstDueDate.day > lastDayOfMonth ? lastDayOfMonth : _firstDueDate.day;
          return DateTime(year, month, day);
      }
    });
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_kMonths[d.month - 1]} ${d.year}';

  // ── Ações ──────────────────────────────────────────────────────────────────

  Future<void> _pickFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _firstDueDate = picked);
  }

  Future<void> _generate() async {
    final nameBase = _nameCtrl.text.trim();
    if (nameBase.isEmpty || _quantity < 1 || _generating) return;

    setState(() => _generating = true);
    try {
      final dates = _generateDates();
      final valor = _valor;
      final rows = List.generate(_quantity, (i) => {
        'task_id': widget.taskId,
        'titulo': '$nameBase / Parcela ${i + 1}',
        'data_vencimento': dates[i].toIso8601String(),
        if (valor != null) 'valor': valor,
        'concluida': false,
        'ordem': i,
      });

      await _repo.createSubtasksBatch(rows);
      widget.onGenerated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao gerar parcelas: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.priorityHigh,
        ));
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dates = _generateDates();
    final nameBase = _nameCtrl.text.trim().isEmpty ? 'Parcela' : _nameCtrl.text.trim();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(22, 22, 26, 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              // CORRIGIDO_PARCELAS_ALTURA: padding top 0 -> 8, para o
              // header (handle + título/subtítulo) não ficar colado/cortado
              // pela borda arredondada superior do Container.
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHandle(),
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildLabel('Nome base'),
                  _buildTextField(_nameCtrl, hint: 'Ex: Aluguel'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildQuantityField()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildValorField()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('Vencimento da 1ª parcela'),
                  _buildDueDateField(),
                  const SizedBox(height: 12),
                  _buildLabel('Frequência'),
                  _buildFrequencyPills(),
                  const SizedBox(height: 16),
                  _buildPreview(dates, nameBase),
                  const SizedBox(height: 12),
                  _buildInfoNote(),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 14),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(9),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gerar Parcelas', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 2),
            Text('Subtarefas com vencimentos automáticos', style: TextStyle(
              fontSize: 12.5, color: AppColors.textSecondary,
            )),
          ],
        ),
      ),
      GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.close, size: 20, color: AppColors.textTertiary),
        ),
      ),
    ],
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(
      fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500,
    )),
  );

  BoxDecoration get _inputDecoration => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.07),
    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    borderRadius: BorderRadius.circular(12),
  );

  Widget _buildTextField(TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) => Container(
    decoration: _inputDecoration,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary),
      ),
    ),
  );

  Widget _buildQuantityField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildLabel('Nº de parcelas'),
      Container(
        decoration: _inputDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text('$_quantity', style: TextStyle(fontSize: 15, color: AppColors.textPrimary))),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _quantity = (_quantity + 1).clamp(1, 360)),
                  child: Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.textSecondary),
                ),
                GestureDetector(
                  onTap: () => setState(() => _quantity = (_quantity - 1).clamp(1, 360)),
                  child: Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildValorField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildLabel('Valor por parcela (R\$)'),
      _buildTextField(_valorCtrl, hint: '0,00', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
    ],
  );

  Widget _buildDueDateField() => GestureDetector(
    onTap: _pickFirstDueDate,
    child: Container(
      decoration: _inputDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(_formatDate(_firstDueDate), style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        ],
      ),
    ),
  );

  Widget _buildFrequencyPills() => Row(
    children: [
      _frequencyPill('monthly', 'Mensal'),
      const SizedBox(width: 8),
      _frequencyPill('biweekly', 'Quinzenal'),
      const SizedBox(width: 8),
      _frequencyPill('weekly', 'Semanal'),
    ],
  );

  Widget _frequencyPill(String id, String label) {
    final selected = _frequency == id;
    return GestureDetector(
      onTap: () => setState(() => _frequency = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(99),
          border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.black.withValues(alpha: 0.85) : AppColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildPreview(List<DateTime> dates, String nameBase) {
    final visible = dates.take(3).toList();
    final remaining = _quantity - visible.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Preview — $_quantity subtarefas', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
              )),
              if (remaining > 0)
                Text('+$remaining mais', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_box_outline_blank, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('$nameBase / Parcela ${i + 1}', style: TextStyle(
                      fontSize: 13.5, color: AppColors.textPrimary,
                    ), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDate(visible[i]), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (_valor != null) ...[
                    const SizedBox(width: 8),
                    Text('R\$ ${_valor!.toStringAsFixed(2)}', style: TextStyle(
                      fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600,
                    )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoNote() => Container(
    decoration: BoxDecoration(
      color: AppColors.priorityLow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('💡', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Após gerar, você pode editar o vencimento de qualquer parcela individualmente abrindo a subtarefa.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _buildFooter() => Row(
    children: [
      Expanded(
        flex: 1,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('Cancelar', style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            )),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: _generating ? null : _generate,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: _generating
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text('Gerar $_quantity Parcelas', style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black,
                  )),
          ),
        ),
      ),
    ],
  );
}
