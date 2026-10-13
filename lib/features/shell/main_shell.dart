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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  static const _pages = [
    HomePage(),
    AssistantPage(),
    GalleryPage(),
    ProfilePage(),
  ];

  var _index = 0;
  var _from = 0;
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _from = _index;
      _index = index;
    });
    _motion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AssistantCubit>()..load()),
        BlocProvider(create: (_) => getIt<GalleryCubit>()..load()),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_motion.value);
            final forward = _index >= _from;
            return Stack(
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _tabLayer(i, t, forward, _pages[i]),
              ],
            );
          },
        ),
        bottomNavigationBar: _ReferenceNav(
          index: _index,
          onSelected: _select,
        ),
      ),
    );
  }

  Widget _tabLayer(int i, double t, bool forward, Widget child) {
    final incoming = i == _index;
    final outgoing = i == _from && _from != _index;
    final shown = incoming || (outgoing && t < 1);
    final opacity = incoming
        ? t
        : outgoing
        ? 1 - t
        : 0.0;
    final dx = incoming
        ? (forward ? 0.045 : -0.045) * (1 - t)
        : outgoing
        ? (forward ? -0.045 : 0.045) * t
        : 0.0;
    return Offstage(
      offstage: !shown,
      child: IgnorePointer(
        ignoring: !incoming,
        child: ExcludeSemantics(
          excluding: !incoming,
          child: FractionalTranslation(
            translation: Offset(dx, 0),
            child: Opacity(opacity: opacity, child: child),
          ),
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
