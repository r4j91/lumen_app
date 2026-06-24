import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, UserAttributes;
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';

// Tela de edição de perfil — acessível via ProductivitySheet ou Settings
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nomeCtrl = TextEditingController();
  final _apelidoCtrl = TextEditingController();
  String? _avatarUrl; // always an https:// URL or null
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _apelidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final meta = supabase.auth.currentUser?.userMetadata ?? {};
      if (mounted) {
        _nomeCtrl.text = meta['nome'] as String? ?? '';
        _apelidoCtrl.text = meta['apelido'] as String? ?? '';
        final url = meta['avatar_url'] as String?;
        // Accept only remote URLs — discard any legacy local file paths
        _avatarUrl = (url != null && url.startsWith('http')) ? url : null;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!kIsWeb)
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                  title: Text('Câmera', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: Text('Galeria', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.priorityHigh),
                  title: Text('Remover foto', style: TextStyle(color: AppColors.priorityHigh)),
                  onTap: () => Navigator.of(ctx).pop(null),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (choice == null && _avatarUrl != null) {
      // Remove avatar
      setState(() => _avatarUrl = null);
      _saveMetaAvatarUrl(null);
      return;
    }
    if (choice == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: choice, imageQuality: 85, maxWidth: 512);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final userId = supabase.auth.currentUser?.id ?? 'unknown';
      final path = '$userId/avatar.jpg';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final url = supabase.storage.from('avatars').getPublicUrl(path);
      // Bust cache by appending timestamp
      final cacheBusted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;
      setState(() => _avatarUrl = cacheBusted);
      await _saveMetaAvatarUrl(cacheBusted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao enviar foto: $e'),
          backgroundColor: AppColors.priorityHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveMetaAvatarUrl(String? url) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {
          'nome': _nomeCtrl.text.trim(),
          'apelido': _apelidoCtrl.text.trim(),
          'avatar_url': _avatarUrl,
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil atualizado'),
            backgroundColor: AppColors.tagGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.priorityHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final email = supabase.auth.currentUser?.email ?? '';
    final displayName = _apelidoCtrl.text.isNotEmpty
        ? _apelidoCtrl.text
        : _nomeCtrl.text.isNotEmpty
            ? _nomeCtrl.text.split(' ').first
            : email.split('@').first;
    final initials = displayName.substring(0, math.min(2, displayName.length)).toUpperCase();
    final hasPhoto = _avatarUrl != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Text('Salvar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent)),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, mq.padding.bottom + 32),
              children: [
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.15),
                            image: hasPhoto
                                ? DecorationImage(
                                    image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: hasPhoto
                              ? null
                              : Center(
                                  child: Text(initials, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.accent)),
                                ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _uploadingPhoto ? AppColors.textTertiary : AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 2),
                            ),
                            child: _uploadingPhoto
                                ? Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                                  )
                                : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Dados
                _SectionLabel('Informações'),
                const SizedBox(height: 8),
                _buildCard(
                  children: [
                    _EditField(label: 'Nome completo', controller: _nomeCtrl, hint: 'Seu nome'),
                    Divider(height: 1, color: AppColors.surfaceVariant),
                    _EditField(label: 'Apelido', controller: _apelidoCtrl, hint: 'Como quer ser chamado'),
                    Divider(height: 1, color: AppColors.surfaceVariant),
                    _ReadOnlyField(label: 'E-mail', value: email),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

// ── Componentes internos ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.6),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  const _EditField({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13.5, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
