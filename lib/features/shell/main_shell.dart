import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/assistant/presentation/assistant_page.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/gallery/presentation/gallery_page.dart';
import 'package:seesay/features/home/presentation/home_page.dart';
import 'package:seesay/features/profile/presentation/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AssistantCubit>()..load()),
        BlocProvider(create: (_) => getIt<GalleryCubit>()..load()),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _index,
          children: const [
            HomePage(),
            AssistantPage(),
            GalleryPage(),
            ProfilePage(),
          ],
        ),
        bottomNavigationBar: _ReferenceNav(
          index: _index,
          onSelected: (index) => setState(() => _index = index),
        ),
      ),
    );
  }
}

class _ReferenceNav extends StatelessWidget {
  const _ReferenceNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Главная'),
    (
      icon: Icons.auto_awesome_outlined,
      selected: Icons.auto_awesome,
      label: 'AI-помощник',
    ),
    (
      icon: Icons.photo_library_outlined,
      selected: Icons.photo_library_rounded,
      label: 'Галерея',
    ),
    (
      icon: Icons.more_horiz_rounded,
      selected: Icons.more_horiz_rounded,
      label: 'Профиль',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE6E8EC))),
        ),
        child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: index == i,
                    label: _items[i].label,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == i ? _items[i].selected : _items[i].icon,
                            color: index == i
                                ? AppColors.accent
                                : AppColors.muted,
                            size: 26,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: index == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: index == i
                                  ? AppColors.accent
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
