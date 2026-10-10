import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsCubit>().state;
    final app = context.watch<AppCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ScreenHeader(
              subtitle: 'Аккаунт',
              title: 'Профиль',
              padding: EdgeInsets.only(bottom: 4),
            ),
            const SizedBox(height: 16),
            _card(
              child: const Text(
                'Кнопка на дужке запускает описание сцены. Двойное касание повторяет ответ. Это приложение не показывает выдуманный кадр, если снимок не был сохранён.',
                style: TextStyle(fontSize: 16, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: [
                  _switchRow(
                    title: 'Демонстрационный режим',
                    subtitle: events.mockMode
                        ? 'События помечены как имитация'
                        : 'Имитация выключена',
                    value: events.mockMode,
                    onChanged: (value) =>
                        context.read<EventsCubit>().setMockMode(value),
                  ),
                  const SizedBox(height: 8),
                  _switchRow(
                    title: 'Фоновый мониторинг',
                    subtitle: events.monitoring
                        ? 'Сервис запущен'
                        : 'Сервис остановлен',
                    value: events.monitoring,
                    onChanged: (value) =>
                        context.read<EventsCubit>().setMonitoring(value),
                  ),
                ],
              ),
            ),
            
            if (events.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  events.error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Последние события',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _card(
              child: events.events.isEmpty
                  ? const Text('Событий пока нет.')
                  : Column(
                      children: [
                        for (final event in events.events.take(12))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.circle,
                                  child: Icon(
                                    Icons.sensors,
                                    color: AppColors.ink,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(event.type.label),
                                      Text(
                                        '${_source(event.source)} · ${event.timestamp.toLocal()}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _card(
              child: InkWell(
                onTap: () => context.push('/settings'),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Специальные возможности'),
                          Text(
                            'Скорость и язык речи',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'О приложении',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'SeeSay, версия 1.0.0. Ответы анализа озвучиваются. Отдельные уведомления о событиях очков не используются.',
              style: TextStyle(height: 1.35),
            ),
            
          ],
        ),
      ),
    );
  }
}

Widget _switchRow({
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _card({required Widget child}) {
  return Material(
    color: AppColors.card,
    elevation: 2,
    shadowColor: const Color(0x14000000),
    borderRadius: BorderRadius.circular(24),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

IconData _eventIcon(RecordedEventType type) {
  return switch (type) {
    RecordedEventType.glassesConnected => Icons.power_settings_new_rounded,
    RecordedEventType.batteryChanged => Icons.battery_full_rounded,
    RecordedEventType.photoCaptured => Icons.videocam_outlined,
    RecordedEventType.textRecognized => Icons.tune_rounded,
    RecordedEventType.sceneAnalysisReady => Icons.auto_awesome_outlined,
    RecordedEventType.glassesDisconnected => Icons.wifi_off_rounded,
    RecordedEventType.deviceError => Icons.error_outline_rounded,
  };
}

String _source(RecordedEventSource source) {
  return switch (source) {
    RecordedEventSource.mock => 'имитация',
    RecordedEventSource.ble => 'очки',
    RecordedEventSource.backend => 'сервер',
  };
}
