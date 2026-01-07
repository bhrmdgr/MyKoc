import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mykoc/pages/premium/premium_view_model.dart';
import 'package:provider/provider.dart';

class PremiumView extends StatefulWidget {
  const PremiumView({super.key});

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  late PremiumViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PremiumViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        body: Consumer<PremiumViewModel>(
          builder: (context, viewModel, child) {
            return Container(
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildHeader(viewModel.isPremium),
                            const SizedBox(height: 40),
                            _buildFeaturesList(),
                            const SizedBox(height: 40),
                            _buildPricingPlans(viewModel),
                            const SizedBox(height: 32),
                            if (viewModel.isPremium) _buildCancelButton(context, viewModel),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomAction(context, viewModel),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPremium) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
          ),
          child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
        ),
        const SizedBox(height: 24),
        Text(
          isPremium ? 'current_subscription'.tr() : 'mykoc_pro'.tr(),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          isPremium ? 'premium_active_info'.tr() : 'pro_subtitle'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      children: [
        _buildFeatureItem(Icons.all_inclusive_rounded, 'unlimited_classes_title'.tr(), 'unlimited_classes_desc'.tr()),
        _buildFeatureItem(Icons.groups_rounded, 'unlimited_students_title'.tr(), 'unlimited_students_desc'.tr()),
        _buildFeatureItem(Icons.block_rounded, 'no_ads_title'.tr(), 'no_ads_desc'.tr()),
        _buildFeatureItem(Icons.analytics_outlined, 'detailed_analytics_title'.tr(), 'detailed_analytics_desc'.tr()),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPlans(PremiumViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          child: _buildPlanCard(
            index: 0,
            title: 'monthly'.tr(),
            price: '₺99.99',
            period: '/mo',
            isSelected: viewModel.selectedPlanIndex == 0,
            onTap: () => viewModel.selectPlan(0),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPlanCard(
            index: 1,
            title: 'yearly'.tr(),
            price: '₺799.99',
            period: '/yr',
            isSelected: viewModel.selectedPlanIndex == 1,
            badge: 'best_value'.tr(),
            onTap: () => viewModel.selectPlan(1),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? Colors.amber : Colors.white.withOpacity(0.2), width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Text(title, style: TextStyle(color: isSelected ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF4338CA) : Colors.white)),
                Text(period, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black54 : Colors.white.withOpacity(0.5))),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -32,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context, PremiumViewModel viewModel) {
    return TextButton(
      onPressed: () => _showCancelDialog(context, viewModel),
      child: Text(
        'cancel_subscription'.tr(),
        style: TextStyle(color: Colors.white.withOpacity(0.5), decoration: TextDecoration.underline),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, PremiumViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: viewModel.isLoading ? null : () => viewModel.handleSubscriptionAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: viewModel.isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                viewModel.isPremium ? 'update_plan'.tr() : 'upgrade_to_pro_button'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('cancel_anytime'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, PremiumViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('cancel_confirm_title'.tr()),
        content: Text('cancel_confirm_desc'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('close'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await viewModel.cancelSubscription();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('subscription_cancelled_success'.tr()), backgroundColor: Colors.green),
                );
              }
            },
            child: Text('cancel_subscription'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}