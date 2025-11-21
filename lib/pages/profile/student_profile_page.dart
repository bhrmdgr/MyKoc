import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/profile/profile_view_model.dart';
import 'package:mykoc/pages/profile/widgets/student_profile_view.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;

  const StudentProfilePage({super.key, required this.studentId});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel();
    // ViewModel'i mentörün öğrenciyi izlemesi için başlatıyoruz
    _viewModel.initializeForStudent(widget.studentId);
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
        // AppBar kaldırıldı, body Stack içine alındı
        body: Stack(
          children: [
            // 1. Ana İçerik (Profil Görünümü)
            Consumer<ProfileViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final profileData = viewModel.profileData;
                if (profileData == null) {
                  return const Center(child: Text("Student data not found"));
                }

                return StudentProfileView(
                  profileData: profileData,
                  viewModel: viewModel,
                );
              },
            ),

            // 2. Geri Butonu (Sol Üst Köşe)
            Positioned(
              top: 50, // SafeArea için biraz boşluk (Status bar altına)
              left: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // Hafif şeffaf arka plan
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white, // Header gradient olduğu için beyaz icon
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}