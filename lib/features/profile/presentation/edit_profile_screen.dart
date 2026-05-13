import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';

part 'edit_profile_screen.g.dart';

// ── Estado do formulário ───────────────────────────────────────────────────────

class EditProfileForm {
  const EditProfileForm({
    this.name        = '',
    this.bio         = '',
    this.instagram   = '',
    this.estado,
    this.cidade      = '',
    this.avatarFile,
    this.isSubmitting = false,
    this.error,
    this.success      = false,
  });

  final String name;
  final String bio;
  final String instagram;
  final String? estado;
  final String cidade;
  final File? avatarFile;
  final bool isSubmitting;
  final String? error;
  final bool success;

  EditProfileForm copyWith({
    String? name, String? bio, String? instagram,
    String? estado, String? cidade, File? avatarFile,
    bool clearAvatar = false,
    bool? isSubmitting, String? error,
    bool clearError = false, bool? success,
  }) => EditProfileForm(
    name:         name         ?? this.name,
    bio:          bio          ?? this.bio,
    instagram:    instagram    ?? this.instagram,
    estado:       estado       ?? this.estado,
    cidade:       cidade       ?? this.cidade,
    avatarFile:   clearAvatar  ? null : avatarFile ?? this.avatarFile,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error:        clearError   ? null : error ?? this.error,
    success:      success      ?? this.success,
  );
}

@riverpod
class EditProfileNotifier extends _$EditProfileNotifier {
  @override
  EditProfileForm build() {
    // Pré-preenche com dados do usuário logado
    final user = ref.watch(currentUserProvider);
    if (user == null) return const EditProfileForm();
    return EditProfileForm(
      name:      user.name,
      bio:       user.bio ?? '',
      instagram: user.instagram ?? '',
      estado:    user.estado,
      cidade:    user.cidade ?? '',
    );
  }

  void setName(String v)      => state = state.copyWith(name: v);
  void setBio(String v)       => state = state.copyWith(bio: v);
  void setInstagram(String v) => state = state.copyWith(instagram: v);
  void setEstado(String? v)   => state = state.copyWith(estado: v);
  void setCidade(String v)    => state = state.copyWith(cidade: v);
  void setAvatarFile(File f)  => state = state.copyWith(avatarFile: f);

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (img != null) setAvatarFile(File(img.path));
  }

  Future<void> submit(BuildContext context) async {
    if (state.name.trim().isEmpty) {
      state = state.copyWith(error: 'O nome é obrigatório.');
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post(
        trpcUrl('users.atualizarPerfil'),
        data: {
          '0': {
            'json': {
              'name':      state.name.trim(),
              'bio':       state.bio.trim().isEmpty ? null : state.bio.trim(),
              'instagram': state.instagram.trim().isEmpty
                  ? null : state.instagram.trim(),
              'estado':    state.estado,
              'cidade':    state.cidade.trim().isEmpty
                  ? null : state.cidade.trim(),
            }
          }
        },
      );
      // TODO: upload de avatar (multipart) quando o backend tiver o endpoint
      await ref.read(authNotifierProvider.notifier).refreshUser();
      state = state.copyWith(isSubmitting: false, success: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado!')),
        );
        context.pop();
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: ErrorHandler.handle(e).message,
      );
    }
  }
}

// ── Tela ───────────────────────────────────────────────────────────────────────

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _igCtrl;
  late final TextEditingController _cidadeCtrl;

  @override
  void initState() {
    super.initState();
    final form = ref.read(editProfileNotifierProvider);
    _nameCtrl   = TextEditingController(text: form.name);
    _bioCtrl    = TextEditingController(text: form.bio);
    _igCtrl     = TextEditingController(text: form.instagram);
    _cidadeCtrl = TextEditingController(text: form.cidade);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _bioCtrl, _igCtrl, _cidadeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  static const _estados = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO',
    'MA','MG','MS','MT','PA','PB','PE','PI','PR',
    'RJ','RN','RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  Widget build(BuildContext context) {
    final form   = ref.watch(editProfileNotifierProvider);
    final notif  = ref.read(editProfileNotifierProvider.notifier);
    final user   = ref.watch(currentUserProvider);
    final tt     = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        title: const Text('Editar perfil',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: form.isSubmitting ? null : () => notif.submit(context),
            child: Text(
              form.isSubmitting ? 'Salvando...' : 'Salvar',
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Avatar ────────────────────────────────────────────────────
          Center(
            child: Stack(
              children: [
                _AvatarPreview(
                  user:       user,
                  localFile:  form.avatarFile,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: notif.pickAvatar,
                    child: Container(
                      width: 34, height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.terra,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Nome ──────────────────────────────────────────────────────
          const _Label('Nome *'),
          const SizedBox(height: 8),
          _Field(controller: _nameCtrl, hint: 'Seu nome completo',
              onChanged: notif.setName),

          const SizedBox(height: 20),

          // ── Bio ───────────────────────────────────────────────────────
          const _Label('Bio'),
          const SizedBox(height: 4),
          Text('Conte um pouco sobre você e suas preferências de viagem.',
              style: tt.bodySmall?.copyWith(color: AppColors.barkMuted)),
          const SizedBox(height: 8),
          _Field(controller: _bioCtrl, hint: 'Ex: Adoro trilhas e gastronomia...',
              onChanged: notif.setBio, maxLines: 3),

          const SizedBox(height: 20),

          // ── Instagram ─────────────────────────────────────────────────
          const _Label('Instagram'),
          const SizedBox(height: 8),
          _Field(controller: _igCtrl,
              hint: '@seu_usuario',
              prefix: const Icon(Icons.alternate_email_rounded,
                  size: 18, color: AppColors.barkMuted),
              onChanged: notif.setInstagram),

          const SizedBox(height: 20),

          // ── Localização ───────────────────────────────────────────────
          const _Label('Onde você mora?'),
          const SizedBox(height: 8),
          Row(children: [
            // Estado
            SizedBox(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sand),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: form.estado,
                    hint: const Text('UF', style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 14,
                        color: AppColors.barkMuted)),
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppColors.barkMuted, size: 18),
                    style: const TextStyle(fontFamily: 'Nunito',
                        fontSize: 14, color: AppColors.bark),
                    onChanged: notif.setEstado,
                    items: [
                      const DropdownMenuItem(value: null,
                          child: Text('–', style: TextStyle(
                              color: AppColors.barkMuted))),
                      ..._estados.map((uf) =>
                          DropdownMenuItem(value: uf, child: Text(uf))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                  controller: _cidadeCtrl,
                  hint: 'Cidade',
                  onChanged: notif.setCidade,
                  capitalization: TextCapitalization.words),
            ),
          ]),

          const SizedBox(height: 24),

          if (form.error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(form.error!,
                  style: const TextStyle(fontFamily: 'Nunito',
                      fontSize: 13, color: AppColors.error)),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: form.isSubmitting ? null : () => notif.submit(context),
              child: form.isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('Salvar alterações'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.user, required this.localFile});
  final UserModel? user;
  final File? localFile;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 52,
      backgroundColor: AppColors.sand,
      backgroundImage: localFile != null
          ? FileImage(localFile!) as ImageProvider
          : (user?.foto != null
              ? CachedNetworkImageProvider(user!.foto!)
              : null),
      child: localFile == null && user?.foto == null
          ? Text(user?.initials ?? '?',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 28,
                  fontWeight: FontWeight.w700, color: AppColors.bark))
          : null,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.titleSmall);
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.prefix,
    this.capitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final Widget? prefix;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    maxLines: maxLines,
    textCapitalization: capitalization,
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
        color: AppColors.bark),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
          color: AppColors.barkMuted),
    ),
  );
}
