import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/home/homeViewModel.dart';
import 'package:mykoc/pages/home/widgets/mentor_home_view.dart';
import 'package:mykoc/pages/home/widgets/student_home_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Provider.of yerine doğrudan yeni bir instance oluşturup initialize ediyoruz
    _viewModel = HomeViewModel();

    // ÖNEMLİ: Widget ağacı çizildikten hemen sonra initialize'ı zorla tetikle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
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
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, child) {
          final homeData = viewModel.homeData;

          if (homeData == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return homeData.isMentor
              ? MentorHomeView(homeData: homeData, viewModel: viewModel)
              : StudentHomeView(homeData: homeData, viewModel: viewModel);
        },
      ),
    );
  }
}