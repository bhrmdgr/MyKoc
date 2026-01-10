import 'package:easy_localization/easy_localization.dart'; // ← Eklendi
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/user_info/user_info_view_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';


class UserInfoView extends StatefulWidget {
  const UserInfoView({super.key});

  @override
  State<UserInfoView> createState() => _UserInfoViewState();
}

class _UserInfoViewState extends State<UserInfoView> {
  late UserInfoViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _viewModel = UserInfoViewModel();
    _viewModel.initialize();

    _nameController = TextEditingController();
    _phoneController = TextEditingController();

    _viewModel.addListener(_updateControllers);
  }

  void _updateControllers() {
    if (_viewModel.userInfo != null) {
      _nameController.text = _viewModel.userInfo!.name;
      _phoneController.text = _viewModel.userInfo!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_updateControllers);
    _viewModel.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Consumer<UserInfoViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.userInfo == null) {
              return Center(child: Text('no_user_data'.tr())); // ✅ GÜNCELLENDİ
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(viewModel),
                  const SizedBox(height: 20),
                  _buildProfileImageSection(viewModel),
                  const SizedBox(height: 24),
                  _buildInfoForm(viewModel),
                  const SizedBox(height: 16),
                  _buildPasswordSection(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserInfoViewModel viewModel) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Text(
                'user_information'.tr(), // ✅ GÜNCELLENDİ
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection(UserInfoViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: (viewModel.userInfo!.profileImageUrl != null &&
                    viewModel.userInfo!.profileImageUrl!.isNotEmpty)
                    ? ClipOval(
                  child: Image.network(
                    viewModel.userInfo!.profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          viewModel.userInfo!.userInitials,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                )
                    : Center(
                  child: Text(
                    viewModel.userInfo!.userInitials,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showImagePickerDialog(viewModel),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            viewModel.userInfo!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.userInfo!.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (viewModel.userInfo!.createdAt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'member_since'.tr(args: [DateFormat('MMM yyyy').format(viewModel.userInfo!.createdAt!)]), // ✅ GÜNCELLENDİ
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoForm(UserInfoViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'personal_information'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'full_name'.tr(), // ✅ GÜNCELLENDİ
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'error_name_empty'.tr(); // ✅ GÜNCELLENDİ
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'phone_optional'.tr(), // ✅ GÜNCELLENDİ
                hintText: '+90 5XX XXX XX XX',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: viewModel.isSaving
                    ? null
                    : () => _saveUserInfo(viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: viewModel.isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  'save_changes'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'security'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showChangePasswordDialog(),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, color: Color(0xFF6B7280),
                      size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'change_password'.tr(), // ✅ GÜNCELLENDİ
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<bool> _checkPermissions({bool isCamera = false}) async {
    if (isCamera) {
      final cameraStatus = await Permission.camera.request();
      return cameraStatus.isGranted;
    } else {
      if (Platform.isAndroid) {
        if (await Permission.photos.isGranted) {
          return true;
        }
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted) {
          return true;
        }

        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
      return true;
    }
  }

  void _showImagePickerDialog(UserInfoViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                      Icons.camera_alt, color: Color(0xFF6366F1)),
                  title: Text('take_photo'.tr()), // ✅ GÜNCELLENDİ
                  onTap: () async {
                    Navigator.pop(context);

                    final hasPermission = await _checkPermissions(
                        isCamera: true);
                    if (!hasPermission) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('camera_permission_required'.tr()), // ✅ GÜNCELLENDİ
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );

                      if (image != null && mounted) {
                        await _uploadProfileImage(viewModel, File(image.path));
                      }
                    } catch (e) {
                      debugPrint('❌ Camera error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('failed_take_photo'.tr()), // ✅ GÜNCELLENDİ
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                      Icons.photo_library, color: Color(0xFF6366F1)),
                  title: Text('choose_gallery'.tr()), // ✅ GÜNCELLENDİ
                  onTap: () async {
                    Navigator.pop(context);

                    final hasPermission = await _checkPermissions(
                        isCamera: false);
                    if (!hasPermission) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('storage_permission_required'.tr()), // ✅ GÜNCELLENDİ
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );

                      if (image != null && mounted) {
                        await _uploadProfileImage(viewModel, File(image.path));
                      }
                    } catch (e) {
                      debugPrint('❌ Gallery error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('failed_pick_image'.tr()), // ✅ GÜNCELLENDİ
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }


  Future<void> _uploadProfileImage(UserInfoViewModel viewModel,
      File imageFile,) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
      const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await viewModel.updateProfileImage(imageFile);

    if (mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'profile_image_updated'.tr() // ✅ GÜNCELLENDİ
              : 'profile_image_failed'.tr()), // ✅ GÜNCELLENDİ
          backgroundColor: success ? const Color(0xFF10B981) : const Color(
              0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _saveUserInfo(UserInfoViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await viewModel.updateUserInfo(
      name: _nameController.text,
      phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'info_updated_success'.tr() // ✅ GÜNCELLENDİ
              : 'info_updated_failed'.tr()), // ✅ GÜNCELLENDİ
          backgroundColor: success ? const Color(0xFF10B981) : const Color(
              0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Text('change_password'.tr()), // ✅ GÜNCELLENDİ
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: !isCurrentPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'current_password'.tr(),
                      // Metin boyutlarını 12 olarak ayarladık
                      labelStyle: const TextStyle(fontSize: 12),
                      floatingLabelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(isCurrentPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() =>
                        isCurrentPasswordVisible = !isCurrentPasswordVisible),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !isNewPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'new_password'.tr(),
                      // Metin boyutlarını 12 olarak ayarladık
                      labelStyle: const TextStyle(fontSize: 12),
                      floatingLabelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(isNewPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                                () => isNewPasswordVisible = !isNewPasswordVisible),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'confirm_new_password'.tr(),
                      // Diğerleri gibi metin boyutu 12
                      labelStyle: const TextStyle(fontSize: 12),
                      floatingLabelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                      // Dikey boşluğu diğerleriyle aynı (12) yaparak kutu boyutlarını eşitledik
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() =>
                        isConfirmPasswordVisible = !isConfirmPasswordVisible),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newPasswordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('error_password_length'.tr()), // ✅ Mevcut key kullanıldı
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }

                  if (newPasswordController.text != confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('error_password_mismatch'.tr()), // ✅ Mevcut key kullanıldı
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);

                  if (!mounted) return;
                  showDialog(
                    context: this.context,
                    barrierDismissible: false,
                    builder: (loadingContext) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    final success = await _viewModel.changePassword(
                      currentPassword: currentPasswordController.text,
                      newPassword: newPasswordController.text,
                    );

                    if (!mounted) return;

                    Navigator.of(this.context).pop();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'password_changed_success'.tr() // ✅ GÜNCELLENDİ
                            : 'password_changed_failed'.tr()), // ✅ GÜNCELLENDİ
                        backgroundColor: success
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;

                    Navigator.of(this.context).pop();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('error_with_message'.tr(args: [e.toString()])), // ✅ GÜNCELLENDİ
                        backgroundColor: const Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                child: Text('change_password'.tr()), // ✅ GÜNCELLENDİ
              ),
            ],
          );
        },
      ),
    );
  }
}