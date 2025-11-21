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
        // Arka plan rengini StudentProfileView ile uyumlu yapıyoruz
        backgroundColor: const Color(0xFFF9FAFB),
        body: Stack(
          // ÖNEMLİ: fit: StackFit.expand sayesinde içerik tüm ekranı kaplar
          // ve StudentProfileView içindeki Scroll özelliği sorunsuz çalışır.
          fit: StackFit.expand,
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

            // 2. Geri Butonu (Sol Üst Köşe - Sabit ve Tıklanabilir)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 0, 0), // Kenar boşlukları
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // Hafif şeffaf
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white, // Header üzerinde beyaz ikon
                        size: 24,
                      ),
                    ),
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