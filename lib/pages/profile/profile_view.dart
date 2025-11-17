import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/profile/profile_view_model.dart';
import 'package:mykoc/pages/profile/widgets/mentor_profile_view.dart';
import 'package:mykoc/pages/profile/widgets/student_profile_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel();
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
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, child) {
          final profileData = viewModel.profileData;

          if (profileData == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return profileData.isMentor
              ? MentorProfileView(profileData: profileData, viewModel: viewModel)
              : StudentProfileView(profileData: profileData, viewModel: viewModel);
        },
      ),
    );
  }
}