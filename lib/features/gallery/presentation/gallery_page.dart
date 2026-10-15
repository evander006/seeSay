import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/app/theme/ui.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GalleryCubit>().state;
    final selected = state.selected;
    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<GalleryCubit>().closeDetail();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            child: selected != null
                ? _Detail(key: ValueKey(selected.id), item: selected)
                : _Grid(key: const ValueKey('grid'), items: state.items),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, super.key});

  final List<SavedResponse> items;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: PageTitle(
              title: 'Галерея',
              subtitle: items.isEmpty ? null : 'Снимков: ${items.length}',
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 44, color: AppColors.muted),
                    SizedBox(height: 12),
                    Text(
                      'Снимков пока нет. Каждый кадр, на который пришёл ответ, появится здесь вместе с ответом.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) => _Tile(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final SavedResponse item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${_kind(item)}, ${clock(item.createdAt)}. ${item.text}',
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.read<GalleryCubit>().open(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Frame(path: item.imagePath, cacheWidth: 400)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${clock(item.createdAt)} · ${_kind(item)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: Gaps.page,
      children: [
        PageTitle(
          title: _kind(item),
          subtitle: _date(item.createdAt),
          trailing: [
            CircleIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Назад к галерее',
              onTap: () => context.read<GalleryCubit>().closeDetail(),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: _Frame(path: item.imagePath, cacheWidth: 1080),
          ),
        ),
        Gaps.between,
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.prompt != null) ...[
                Text(
                  item.prompt!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 6),
              ],
              Text(item.text, style: const TextStyle(fontSize: 18, height: 1.4)),
            ],
          ),
        ),
        Gaps.between,
        PrimaryButton(
          id: 'gallery-replay',
          label: 'Прослушать',
          icon: Icons.volume_up_rounded,
          onTap: () => context.read<GalleryCubit>().replay(item),
        ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.path, required this.cacheWidth});

  final String? path;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.circle,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
      ),
    );
    final file = path;
    if (file == null) return placeholder;
    return Image.file(
      File(file),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

String _kind(SavedResponse item) =>
    item.type == ResponseType.ocr ? 'Текст' : 'Сцена';

String _date(DateTime time) {
  final local = time.toLocal();
  const months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  return '${local.day} ${months[local.month - 1]}, ${clock(local)}';
}
