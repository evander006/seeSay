import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/background_access.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/assistant/presentation/assistant_page.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/gallery/presentation/gallery_page.dart';
import 'package:seesay/features/home/presentation/home_page.dart';
import 'package:seesay/features/settings/presentation/settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  var _index = 0;
  late final AnimationController _fade;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    _pages = [
      const HomePage(),
      const AssistantPage(),
      const GalleryPage(),
      SettingsPage(
        background: getIt<BackgroundAccess>(),
        onOpenSystemSettings: () => getIt<PermissionService>().openSettings(),
      ),
    ];
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AssistantCubit>()..load()),
        BlocProvider(create: (_) => getIt<GalleryCubit>()..load()),
      ],
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(0);
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              for (var i = 0; i < _pages.length; i++)
                Offstage(
                  offstage: i != _index,
                  child: TickerMode(
                    enabled: i == _index,
                    child: ExcludeSemantics(
                      excluding: i != _index,
                      child: FadeTransition(
                        opacity: i == _index ? _fade : kAlwaysCompleteAnimation,
                        child: _pages[i],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(0xFFDCE8FF),
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded, color: AppColors.accent),
                label: 'Помощник',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accent,
                ),
                label: 'Галерея',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded, color: AppColors.accent),
                label: 'Настройки',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
