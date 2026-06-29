import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../services/haptic_service.dart';
import '../../services/supabase_client.dart';
import '../../theme/app_colors.dart';
import '../pressable.dart';

String formatTaskCommentDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
  if (diff.inHours < 24) return '${diff.inHours}h atrás';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// Carrega e envia comentários de tarefa (extraído de TaskDetailSheet).
class TaskDetailCommentsService {
  TaskDetailCommentsService._();

  static Future<List<Map<String, dynamic>>> loadComments(String taskId) async {
    final rows = await supabase
        .from('task_comments')
        .select('id, conteudo, created_at, user_id')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> sendComment({
    required String taskId,
    required String text,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    await supabase.from('task_comments').insert({
      'task_id': taskId,
      'conteudo': text,
      if (userId != null) 'user_id': userId,
    });
    HapticService().selectionClick();
  }
}

class TaskDetailCommentsList extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> comments;

  const TaskDetailCommentsList({
    super.key,
    required this.loading,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (comments.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (_, i) {
        final c = comments[i];
        final texto = c['conteudo'] as String? ?? '';
        final createdAt =
            c['created_at'] != null ? DateTime.tryParse(c['created_at'] as String) : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textTertiary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        texto,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          formatTaskCommentDate(createdAt),
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TaskDetailCommentFooter extends StatelessWidget {
  final TextEditingController commentCtrl;
  final double bottomPad;
  final VoidCallback onSend;

  const TaskDetailCommentFooter({
    super.key,
    required this.commentCtrl,
    required this.bottomPad,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final borderTop = Border(
      top: BorderSide(color: AppColors.surfaceVariant.withValues(alpha: 0.6), width: 0.5),
    );

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: borderTop),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPad),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              HugeIcon(icon: HugeIcons.strokeRoundedAttachment01, size: 17, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: commentCtrl,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  cursorColor: AppColors.accent,
                  cursorWidth: 1.5,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Comentário...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: commentCtrl,
                builder: (_, value, __) {
                  final hasComment = value.text.trim().isNotEmpty;
                  return Pressable(
                    onTap: hasComment ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasComment
                            ? AppColors.accent
                            : AppColors.textTertiary.withValues(alpha: 0.2),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowUp01,
                        size: 16,
                        color: hasComment ? AppColors.background : AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
