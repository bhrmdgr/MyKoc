import 'package:easy_localization/easy_localization.dart'; // ← Eklendi
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/settings/settings_view_model.dart';
import 'package:mykoc/pages/settings/settings_model.dart';
import 'package:mykoc/pages/user_info/user_info_view.dart';
import 'package:mykoc/pages/user_info/user_info_view_model.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Consumer<SettingsViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.settingsData == null) {
              return Center(child: Text('no_data_available'.tr())); // ✅ GÜNCELLENDİ
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(viewModel.settingsData!),
                  const SizedBox(height: 20),
                  _buildUserInfoSection(context, viewModel.settingsData!),
                  const SizedBox(height: 16),
                  _buildPreferencesSection(context),
                  const SizedBox(height: 16),
                  _buildSupportSection(context),
                  const SizedBox(height: 16),
                  _buildDangerZone(context),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(SettingsModel settingsData) {
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
                'settings_title'.tr(), // ✅ GÜNCELLENDİ
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

  Widget _buildUserInfoSection(BuildContext context,
      SettingsModel settingsData) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserInfoView()),
        );
      },
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                    Icons.person_outline, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'user_information'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: (settingsData.profileImageUrl != null &&
                      settingsData.profileImageUrl!.isNotEmpty)
                      ? ClipOval(
                    child: Image.network(
                      settingsData.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            settingsData.userInitials,
                            style: const TextStyle(
                              fontSize: 24,
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
                      settingsData.userInitials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settingsData.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settingsData.userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          settingsData.roleDisplayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
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
                Icon(Icons.tune_outlined, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'preferences'.tr(), // ✅ GÜNCELLENDİ
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          _buildSettingItem(
            icon: Icons.language_outlined,
            title: 'language'.tr(), // ✅ GÜNCELLENDİ
            subtitle: context.locale.languageCode == 'tr' ? 'Türkçe' : 'English',
            onTap: () => _showLanguageDialog(context),
          ),
          _buildDivider(),
          // ✅ BİLDİRİM SWITCH ÖĞESİ EKLENDİ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: Color(0xFF6B7280), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'notifications'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'manage_notifications'.tr(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _viewModel.settingsData?.isNotificationsEnabled ?? true,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (bool value) {
                    _viewModel.toggleNotifications(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
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
                Icon(Icons.help_outline, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'support_legal'.tr(), // ✅ GÜNCELLENDİ
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          _buildSettingItem(
            icon: Icons.privacy_tip_outlined,
            title: 'privacy_policy'.tr(), // ✅ GÜNCELLENDİ
            onTap: () => _showComingSoonDialog(context, 'privacy_policy'.tr()),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.description_outlined,
            title: 'terms_of_service'.tr(), // ✅ GÜNCELLENDİ
            onTap: () => _showComingSoonDialog(context, 'terms_of_service'.tr()),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'about'.tr(), // ✅ GÜNCELLENDİ
            subtitle: 'version'.tr(args: ['1.0.0']), // ✅ GÜNCELLENDİ
            onTap: () => _showAboutDialog(context),
          ),
          _buildDivider(),
          _buildSettingItem(
            icon: Icons.support_agent_outlined,
            title: 'help_support'.tr(), // ✅ GÜNCELLENDİ
            onTap: () => _showComingSoonDialog(context, 'help_support'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingItem(
            icon: Icons.delete_forever_outlined,
            title: 'delete_account'.tr(), // ✅ GÜNCELLENDİ
            subtitle: 'delete_account_subtitle'.tr(), // ✅ GÜNCELLENDİ
            onTap: () => _showDeleteAccountDialog(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFEF4444) : const Color(
                  0xFF6B7280),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text('select_language'.tr()), // ✅ GÜNCELLENDİ
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageOption(context, 'English', '🇬🇧', const Locale('en', 'US')),
                _buildLanguageOption(context, 'Türkçe', '🇹🇷', const Locale('tr', 'TR')),
              ],
            ),
          ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String language,
      String flag, Locale locale) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(language),
      onTap: () {
        Navigator.pop(context);
        context.setLocale(locale); // easy_localization ile dil değişimi (Aktif edildi)
        _viewModel.changeLanguage(language);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('language_changed'.tr(args: [language])), // ✅ GÜNCELLENDİ
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('coming_soon'.tr()), // ✅ GÜNCELLENDİ
              ],
            ),
            content: Text(
                'feature_coming_soon'.tr(args: [feature])), // ✅ GÜNCELLENDİ
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ok'.tr()), // ✅ GÜNCELLENDİ
              ),
            ],
          ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('about_title'.tr()), // ✅ GÜNCELLENDİ
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app_description'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('version'.tr(args: ['1.0.0'])), // ✅ GÜNCELLENDİ
                const SizedBox(height: 8),
                Text(
                  'platform_summary'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'all_rights_reserved'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('close'.tr()), // ✅ GÜNCELLENDİ
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final reasonController = TextEditingController();
    DeleteReason? selectedReason;

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_outlined,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('delete_account'.tr()), // ✅ GÜNCELLENDİ
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'delete_account_warning'.tr(), // ✅ GÜNCELLENDİ
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'delete_account_data_loss'.tr(), // ✅ GÜNCELLENDİ
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'delete_reason_question'.tr(), // ✅ GÜNCELLENDİ
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...DeleteReason.values.map((reason) {
                        return RadioListTile<DeleteReason>(
                          title: Text(
                            _getReasonDisplayText(reason),
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: reason,
                          groupValue: selectedReason,
                          onChanged: (value) {
                            setState(() {
                              selectedReason = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                      if (selectedReason == DeleteReason.other) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'delete_reason_hint'.tr(), // ✅ GÜNCELLENDİ
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: selectedReason == null
                          ? null
                          : () async {
                        Navigator.pop(context);

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                        );

                        final deleteReason = DeleteAccountReason(
                          reason: selectedReason!,
                          additionalFeedback: selectedReason ==
                              DeleteReason.other
                              ? reasonController.text
                              : null,
                        );

                        final success = await _viewModel.deleteAccount(
                          context: context,
                          deleteReason: deleteReason,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // Close loading

                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('failed_delete_account'.tr()), // ✅ GÜNCELLENDİ
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'delete_my_account_button'.tr(), // ✅ GÜNCELLENDİ
                        style: TextStyle(
                          color: selectedReason == null
                              ? Colors.white54
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  String _getReasonDisplayText(DeleteReason reason) {
    switch (reason) {
      case DeleteReason.notUseful:
        return 'delete_reason_not_useful'.tr(); // ✅ GÜNCELLENDİ
      case DeleteReason.foundAlternative:
        return 'delete_reason_alternative'.tr(); // ✅ GÜNCELLENDİ
      case DeleteReason.privacyConcerns:
        return 'delete_reason_privacy'.tr(); // ✅ GÜNCELLENDİ
      case DeleteReason.tooManyNotifications:
        return 'delete_reason_notifications'.tr(); // ✅ GÜNCELLENDİ
      case DeleteReason.technicalIssues:
        return 'delete_reason_technical'.tr(); // ✅ GÜNCELLENDİ
      case DeleteReason.other:
        return 'delete_reason_other'.tr(); // ✅ GÜNCELLENDİ
    }
  }
}