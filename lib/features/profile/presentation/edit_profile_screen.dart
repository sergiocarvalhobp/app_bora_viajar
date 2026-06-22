import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/ui/bv_forest_app_bar.dart';
import '../../../core/widgets/app_notch_shell.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';

part 'edit_profile_screen.g.dart';

// ── Estado do formulário ───────────────────────────────────────────────────────

class EditProfileForm {
  const EditProfileForm({
    this.name = '',
    this.bio = '',
    this.instagram = '',
    this.estado,
    this.cidade = '',
    this.avatarFile,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  final String name;
  final String bio;
  final String instagram;
  final String? estado;
  final String cidade;
  final File? avatarFile;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  EditProfileForm copyWith({
    String? name,
    String? bio,
    String? instagram,
    String? estado,
    String? cidade,
    File? avatarFile,
    bool clearAvatar = false,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) =>
      EditProfileForm(
        name: name ?? this.name,
        bio: bio ?? this.bio,
        instagram: instagram ?? this.instagram,
        estado: estado ?? this.estado,
        cidade: cidade ?? this.cidade,
        avatarFile: clearAvatar ? null : avatarFile ?? this.avatarFile,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : error ?? this.error,
        successMessage:
            clearSuccess ? null : successMessage ?? this.successMessage,
      );
}

@riverpod
class EditProfileNotifier extends _$EditProfileNotifier {
  @override
  EditProfileForm build() {
    // read (não watch): evita reset do formulário quando applyUserProfile atualiza o auth.
    final user = ref.read(currentUserProvider);
    if (user == null) return const EditProfileForm();
    return EditProfileForm(
      name: user.name,
      bio: user.bio ?? '',
      instagram: user.instagram ?? '',
      estado: user.estado,
      cidade: user.cidade ?? '',
    );
  }

  void setName(String v) =>
      state = state.copyWith(name: v, clearSuccess: true, clearError: true);
  void setBio(String v) =>
      state = state.copyWith(bio: v, clearSuccess: true, clearError: true);
  void setInstagram(String v) => state =
      state.copyWith(instagram: v, clearSuccess: true, clearError: true);
  void setEstado(String? v) =>
      state = state.copyWith(estado: v, clearSuccess: true, clearError: true);
  void setCidade(String v) =>
      state = state.copyWith(cidade: v, clearSuccess: true, clearError: true);
  void setAvatarFile(File f) => state =
      state.copyWith(avatarFile: f, clearSuccess: true, clearError: true);

  Future<void> pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      maxWidth: 480,
      maxHeight: 480,
      imageQuality: 65,
    );
    if (img != null) setAvatarFile(File(img.path));
  }

  Future<void> submit() async {
    if (state.name.trim().isEmpty) {
      state = state.copyWith(error: 'O nome é obrigatório.');
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );
    String? avatarWarning;
    try {
      final dio = ref.read(apiClientProvider);
      String? avatarPayload;
      if (state.avatarFile != null) {
        avatarPayload = _fileToDataUrl(state.avatarFile!);
      }

      var response =
          await _patchProfile(dio, form: state, avatarUrl: avatarPayload);
      var status = response.statusCode ?? 0;

      // Dio não lança em 403/413 (validateStatus < 500) — tratar pelo statusCode.
      if (avatarPayload != null && (status == 403 || status == 413)) {
        response = await _patchProfile(dio, form: state);
        status = response.statusCode ?? 0;
        avatarWarning =
            'Nome e dados salvos, mas a foto não foi aceita pelo servidor. '
            'Tente uma imagem menor.';
        avatarPayload = null;
      }

      if (status >= 400) {
        throw ErrorHandler.handle(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }

      _applyProfileResponse(
        ref,
        response,
        form: state,
        avatarUrl: avatarPayload,
      );

      state = state.copyWith(
        isSubmitting: false,
        successMessage: avatarWarning ?? 'Perfil atualizado com sucesso!',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: ErrorHandler.handle(e).message,
        clearSuccess: true,
      );
    }
  }

  static const _maxAvatarBase64Chars = 320000;

  String _fileToDataUrl(File file) {
    final bytes = file.readAsBytesSync();
    final b64 = base64Encode(bytes);
    final lower = file.path.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,$b64';
    if (dataUrl.length > _maxAvatarBase64Chars) {
      throw const ValidationException(
        'Foto muito grande. Escolha outra imagem ou tire uma foto mais próxima.',
      );
    }
    return dataUrl;
  }

  Future<Response<dynamic>> _patchProfile(
    Dio dio, {
    required EditProfileForm form,
    String? avatarUrl,
  }) {
    return dio.patch(
      '${AppConstants.restApiPrefix}/profile/me',
      data: {
        'name': form.name.trim(),
        'bio': form.bio.trim().isEmpty ? null : form.bio.trim(),
        'instagram':
            form.instagram.trim().isEmpty ? null : form.instagram.trim(),
        'estadoResidencia': form.estado,
        'cidadeResidencia':
            form.cidade.trim().isEmpty ? null : form.cidade.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
  }

  void _applyProfileResponse(
    Ref ref,
    Response<dynamic> response, {
    required EditProfileForm form,
    String? avatarUrl,
  }) {
    final auth = ref.read(authNotifierProvider.notifier);
    final current = ref.read(currentUserProvider);

    if (response.data is Map) {
      try {
        auth.applyUserProfile(
          UserModel.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          ),
        );
        return;
      } catch (_) {
        // Resposta 200 com JSON inesperado — usa merge local abaixo.
      }
    }

    if (current != null) {
      auth.applyUserProfile(
        current.copyWith(
          name: form.name.trim(),
          bio: form.bio.trim().isEmpty ? null : form.bio.trim(),
          instagram:
              form.instagram.trim().isEmpty ? null : form.instagram.trim(),
          estado: form.estado,
          cidade: form.cidade.trim().isEmpty ? null : form.cidade.trim(),
          foto: avatarUrl ?? current.foto,
        ),
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
    _nameCtrl = TextEditingController(text: form.name);
    _bioCtrl = TextEditingController(text: form.bio);
    _igCtrl = TextEditingController(text: form.instagram);
    _cidadeCtrl = TextEditingController(text: form.cidade);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _bioCtrl, _igCtrl, _cidadeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Sair da conta?',
          style: TextStyle(fontFamily: 'DMSerifDisplay'),
        ),
        content: const Text(
          'Sua sessão será encerrada e os dados locais apagados. '
          'Será necessário entrar novamente.',
          style: TextStyle(fontFamily: 'Nunito', height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sair',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (sair != true || !context.mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
  }

  static const _estados = [
    'AC',
    'AL',
    'AM',
    'AP',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MG',
    'MS',
    'MT',
    'PA',
    'PB',
    'PE',
    'PI',
    'PR',
    'RJ',
    'RN',
    'RO',
    'RR',
    'RS',
    'SC',
    'SE',
    'SP',
    'TO',
  ];

  /// UF válida para o [DropdownButton] — valor fora da lista quebra o build.
  static String? _resolveEstadoValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uf = raw.trim().toUpperCase();
    return _estados.contains(uf) ? uf : null;
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(editProfileNotifierProvider);
    final notif = ref.read(editProfileNotifierProvider.notifier);
    final user = ref.watch(currentUserProvider);
    final estadoValue = _resolveEstadoValue(form.estado);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final listBottom =
        keyboardOpen ? 16.0 : AppNotchShell.bottomBarClearance(context);

    // Tema claro fixo — evita inputs/labels escuros com ThemeMode.system em dark.
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppColors.cream,
        // Shell pai já redimensiona com o teclado — evita body com altura 0.
        resizeToAvoidBottomInset: false,
        appBar: BvForestAppBar(
          title: 'Editar perfil',
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Sair da conta',
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + listBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarSourceSheet(context, notif),
                      child: Stack(
                        children: [
                          _AvatarPreview(
                            user: user,
                            localFile: form.avatarFile,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: AppColors.terra,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Nome ──────────────────────────────────────────────────────
              const _Label('Nome *'),
              const SizedBox(height: 8),
              _Field(
                  controller: _nameCtrl,
                  hint: 'Seu nome completo',
                  onChanged: notif.setName),

              const SizedBox(height: 20),

              // ── Bio ───────────────────────────────────────────────────────
              const _Label('Bio'),
              const SizedBox(height: 4),
              const Text(
                'Conte um pouco sobre você e suas preferências de viagem.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.barkMuted,
                ),
              ),
              const SizedBox(height: 8),
              _Field(
                  controller: _bioCtrl,
                  hint: 'Ex: Adoro trilhas e gastronomia...',
                  onChanged: notif.setBio,
                  maxLines: 3),

              const SizedBox(height: 20),

              // ── Instagram ─────────────────────────────────────────────────
              const _Label('Instagram'),
              const SizedBox(height: 8),
              _Field(
                  controller: _igCtrl,
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
                        value: estadoValue,
                        hint: const Text('UF',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: AppColors.barkMuted)),
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded,
                            color: AppColors.barkMuted, size: 18),
                        style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            color: AppColors.bark),
                        onChanged: notif.setEstado,
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('–',
                                  style:
                                      TextStyle(color: AppColors.barkMuted))),
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

              if (form.successMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.forest,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          form.successMessage!,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.forest,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (form.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    form.error!,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: form.isSubmitting ? null : notif.submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.sand,
                    disabledForegroundColor: AppColors.barkMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: form.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Salvar alterações',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarSourceSheet(
    BuildContext context,
    EditProfileNotifier notif,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto do perfil',
                style: ctx.appText.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.forest),
                title: const Text('Escolher da galeria',
                    style: TextStyle(fontFamily: 'Nunito')),
                onTap: () {
                  Navigator.pop(ctx);
                  notif.pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.forest),
                title: const Text('Tirar foto',
                    style: TextStyle(fontFamily: 'Nunito')),
                onTap: () {
                  Navigator.pop(ctx);
                  notif.pickAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.user, required this.localFile});

  static const double _radius = 52;
  static const double _size = _radius * 2;

  final UserModel? user;
  final File? localFile;

  @override
  Widget build(BuildContext context) {
    if (localFile != null) {
      return CircleAvatar(
        radius: _radius,
        backgroundColor: AppColors.sand,
        backgroundImage: FileImage(localFile!),
      );
    }

    final provider = avatarImageProvider(user?.foto);
    if (provider == null) return _initialsAvatar();

    return ClipOval(
      child: SizedBox(
        width: _size,
        height: _size,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(fillParent: true),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _initialsAvatar(fillParent: true, showLoader: true);
          },
        ),
      ),
    );
  }

  Widget _initialsAvatar({bool fillParent = false, bool showLoader = false}) {
    final initials = Text(
      user?.initials ?? '?',
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.bark,
      ),
    );

    if (fillParent) {
      return Container(
        width: _size,
        height: _size,
        color: AppColors.sand,
        alignment: Alignment.center,
        child: showLoader
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.forest,
                ),
              )
            : initials,
      );
    }

    return CircleAvatar(
      radius: _radius,
      backgroundColor: AppColors.sand,
      child: showLoader
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.forest,
              ),
            )
          : initials,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.bark,
        ),
      );
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

  static const _radius = 14.0;

  static InputDecoration _decoration(String hint, {Widget? prefix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: AppColors.sand),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.forest, width: 2),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        color: AppColors.barkMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        textCapitalization: capitalization,
        cursorColor: AppColors.forest,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.bark,
        ),
        decoration: _decoration(hint, prefix: prefix),
      );
}
