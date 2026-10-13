import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GalleryCubit>().state;
    final selected = state.selected;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(
              subtitle: 'Снимки',
              title: 'Галерея',
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: selected != null
                    ? _Detail(key: ValueKey(selected.id), item: selected)
                    : state.items.isEmpty
                  ? const KeyedSubtree(
                      key: ValueKey('gallery-empty'),
                      child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.circle,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Снимков пока нет. Кадр появится здесь только после реального сохранения.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  : ListView.separated(
                      key: const ValueKey('gallery-list'),
                      padding: const EdgeInsets.all(16),
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return Material(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                context.read<GalleryCubit>().open(item),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppColors.circle,
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _stamp(item),
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({super.key, required this.item});

  final SavedResponse item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Файл изображения не сохранён. Ниже только текст ответа.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  item.text,
                  style: const TextStyle(fontSize: 20, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(_stamp(item)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          onPressed: () => context.read<GalleryCubit>().replay(item),
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Прослушать'),
        ),
        TextButton(
          onPressed: () => context.read<GalleryCubit>().closeDetail(),
          child: const Text('Назад к списку'),
        ),
      ],
    );
  }
}

String _stamp(SavedResponse item) {
  final local = item.createdAt.toLocal();
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final kind = item.type == ResponseType.ocr ? 'текст' : 'сцена';
  return '$clock · $kind';
}
