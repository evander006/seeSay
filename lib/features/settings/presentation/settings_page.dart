import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onOpenSystemSettings, super.key});

  final Future<void> Function() onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<AccessibilityCubit, AccessibilityState>(
          builder: (context, access) {
            return BlocBuilder<AppCubit, AppState>(
              builder: (context, app) {
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    const ScreenHeader(
                      subtitle: 'Приложение',
                      title: 'Настройки',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Скорость речи ${access.speechRate.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    Slider(
                      value: access.speechRate,
                      min: 0.5,
                      max: 2,
                      divisions: 15,
                      label: access.speechRate.toStringAsFixed(1),
                      onChanged: (value) => unawaited(
                        context.read<AccessibilityCubit>().setSpeechRate(value),
                      ),
                    ),
                    _choice(
                      context,
                      id: 'lang-ru',
                      label: 'Русский язык',
                      selected: access.language == 'ru-RU',
                      onTap: () => context
                          .read<AccessibilityCubit>()
                          .setLanguage('ru-RU'),
                    ),
                    _choice(
                      context,
                      id: 'lang-en',
                      label: 'English',
                      selected: access.language == 'en-US',
                      onTap: () => context
                          .read<AccessibilityCubit>()
                          .setLanguage('en-US'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Очки: ${app.useMockGlasses ? 'демонстрационный режим' : 'SeeSay'}. '
                        'Камера: ${app.useMockCamera ? 'демонстрационная' : 'устройства'}. '
                        'Анализ: ${app.useMockApi ? 'демонстрационный ответ' : 'сервер'}.',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    if (app.useMockGlasses)
                      _link(
                        context,
                        id: 'simulate',
                        label: 'Имитировать кнопку фото на очках',
                        onTap: () => context
                            .read<ConnectionCubit>()
                            .simulatePhotoTrigger(),
                      ),
                    _link(
                      context,
                      id: 'history',
                      label: 'История ответов',
                      onTap: () => context.push('/history'),
                    ),
                    _link(
                      context,
                      id: 'system-settings',
                      label: 'Открыть настройки приложения',
                      onTap: onOpenSystemSettings,
                    ),
                    _link(
                      context,
                      id: 'back-home',
                      label: 'Назад на главный экран',
                      onTap: () => context.go('/home'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context, {
    required String id,
    required String label,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    return SizedBox(
      height: 84,
      child: AccessibleAction(
        id: id,
        label: label,
        hint: selected ? 'Выбрано' : 'Двойное нажатие для активации',
        onTap: () => unawaited(onTap()),
        child: ColoredBox(
          color: selected ? const Color(0xFFD6E6FF) : AppColors.card,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                selected ? '$label. Выбрано' : label,
                style: const TextStyle(color: AppColors.text, fontSize: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(
    BuildContext context, {
    required String id,
    required String label,
    required FutureOr<void> Function() onTap,
  }) {
    return SizedBox(
      height: 84,
      child: AccessibleAction(
        id: id,
        label: label,
        hint: 'Двойное нажатие для активации',
        onTap: () => unawaited(Future<void>.sync(onTap)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.accent)),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                style: const TextStyle(color: AppColors.text, fontSize: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
