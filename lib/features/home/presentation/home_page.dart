import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/features/home/presentation/glasses_artwork.dart';
import 'package:seesay/core/accessibility/touch_exploration_scope.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/app_cubit.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: TouchExplorationScope(
          audio: scope.audio,
          feedback: scope.feedback,
          customSpeechEnabled: () =>
              context.read<AccessibilityCubit>().state.customTouchSpeech,
          child: const _HomeBody(),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppCubit>().state;
    final link = context.watch<ConnectionCubit>().state;
    final vision = context.watch<VisionCubit>().state;
    final ocr = context.watch<OcrCubit>().state;
    final events = context.watch<EventsCubit>().state;
    final pipeline = pipelineLabel(vision, ocr);
    final result = resultLabel(vision, ocr);
    final connection = _connectionLabel(link.status);
    final failed =
        vision.status == VisionStatus.error || ocr.status == OcrStatus.error;
    final demo = app.useMockGlasses || app.useMockApi || events.mockMode;
    final simulated = app.useMockGlasses || events.mockMode;
    final busy = link.status == ConnectionStatus.connecting;
    return Column(
      children: [
        _Header(demo: demo, events: events.events.length),
        Expanded(
          flex: 6,
          child: _GlassesStage(
            enabled: !busy,
            label: connection.semantics,
            hint: connection.hint,
            onConnect: () => unawaited(_toggleConnection(context)),
          ),
        ),
        Expanded(
          flex: 5,
          child: _ControlCard(
            connection: connection,
            connectEnabled: !busy,
            onConnect: () => unawaited(_toggleConnection(context)),
            battery: link.battery,
            simulated: simulated,
            connected: link.status == ConnectionStatus.connected,
            sceneActive: _actionOn(vision.status.name),
            textActive: _actionOn(ocr.status.name),
            monitoring: events.monitoring,
            pipeline: pipeline,
            result: result,
            failed: failed,
            demo: demo,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleConnection(BuildContext context) async {
    final cubit = context.read<ConnectionCubit>();
    if (cubit.state.status == ConnectionStatus.connected) {
      await cubit.disconnect();
      return;
    }
    await cubit.connect();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.demo, required this.events});

  final bool demo;
  final int events;

  @override
  Widget build(BuildContext context) {
    return ScreenHeader(
      subtitle: _greeting(),
      title: 'SeeSay User',
      trailing: [
        CircleIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Последние события',
          badge: events > 0,
          onTap: () => _showEvents(context),
        ),
      ],
    );
  }

  void _showEvents(BuildContext context) {
    final items = context.read<EventsCubit>().state.events;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Последние события',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text('Событий пока нет.')
              else
                for (final event in items.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event.type.label),
                    subtitle: Text(event.text ?? event.source.name),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassesStage extends StatelessWidget {
  const _GlassesStage({
    required this.enabled,
    required this.label,
    required this.hint,
    required this.onConnect,
  });

  final bool enabled;
  final String label;
  final String hint;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          constraints.maxWidth * 0.78,
          constraints.maxHeight * 0.92,
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            GlassesRing(diameter: side),
            GlassesArtwork(width: side * 0.92),
            Positioned(
              left: (constraints.maxWidth - side) / 2 - 4,
              top: constraints.maxHeight / 2 + side * 0.08,
              child: AccessibleAction(
                id: 'connection-quick',
                label: label,
                hint: hint,
                enabled: enabled,
                onTap: onConnect,
                child: const _FilledDisc(icon: Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.connection,
    required this.connectEnabled,
    required this.onConnect,
    required this.connected,
    required this.sceneActive,
    required this.textActive,
    required this.simulated,
    required this.monitoring,
    required this.pipeline,
    required this.failed,
    required this.demo,
    this.battery,
    this.result,
  });

  final _ConnectionCopy connection;
  final bool connectEnabled;
  final VoidCallback onConnect;
  final bool connected;
  final bool sceneActive;
  final bool textActive;
  final int? battery;
  final bool simulated;
  final bool monitoring;
  final String pipeline;
  final String? result;
  final bool failed;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final charge = battery == null ? '—' : '$battery%';
    final chargeCaption = battery == null
        ? 'Заряд неизвестен'
        : simulated
        ? 'Заряд · имитация'
        : 'Заряд очков';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: RoundAction(
                    icon: Icons.battery_full_rounded,
                    title: charge,
                    caption: chargeCaption,
                  ),
                ),
                Expanded(
                  child: AccessibleAction(
                    key: const Key('action-photo'),
                    id: 'photo',
                    label: 'Описать, что вокруг',
                    hint: 'Двойное нажатие для активации',
                    onTap: () => unawaited(
                      context.read<VisionCubit>().analyzeWhatIsInFront(),
                    ),
                    child: RoundAction(
                      icon: Icons.videocam_outlined,
                      title: 'Что вокруг',
                      caption: 'Сцена',
                      filled: sceneActive,
                      fillColor: const Color(0xFFE85D7A),
                    ),
                  ),
                ),
                Expanded(
                  child: AccessibleAction(
                    key: const Key('action-ocr'),
                    id: 'ocr',
                    label: 'Прочитать текст',
                    hint: 'Двойное нажатие для активации',
                    onTap: () =>
                        unawaited(context.read<OcrCubit>().readTextInFront()),
                    child: RoundAction(
                      icon: Icons.tune_rounded,
                      title: 'Текст',
                      caption: 'Прочитать',
                      filled: textActive,
                      fillColor: const Color(0xFF5B6CFF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AccessibleAction(
                    id: 'connection',
                    label: connection.semantics,
                    hint: connection.hint,
                    enabled: connectEnabled,
                    onTap: onConnect,
                    child: RoundAction(
                      icon: Icons.power_settings_new_rounded,
                      title: connection.title,
                      caption: 'Подключение',
                      filled: connected,
                      fillColor: AppColors.ok,
                    ),
                  ),
                ),
                Expanded(
                  child: AccessibleAction(
                    key: const Key('action-repeat'),
                    id: 'repeat',
                    label: 'Повторить последний ответ',
                    hint: 'Двойное нажатие для активации',
                    onTap: () => unawaited(AppScope.of(context).repeatLast()),
                    child: const RoundAction(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Повтор',
                      caption: 'Последний ответ',
                      filled: true,
                    ),
                  ),
                ),
                Expanded(
                  child: AccessibleAction(
                    id: 'monitor',
                    label: monitoring
                        ? 'Фоновый мониторинг включён'
                        : 'Фоновый мониторинг выключен',
                    hint: 'Двойное нажатие, чтобы переключить',
                    onTap: () => unawaited(
                      context.read<EventsCubit>().setMonitoring(!monitoring),
                    ),
                    child: RoundAction(
                      icon: monitoring
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      title: monitoring ? 'Вкл' : 'Выкл',
                      caption: 'Мониторинг',
                      filled: monitoring,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              pipeline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: failed ? AppColors.danger : AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 6),
              Text(
                result!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ],
            if (demo) ...[
              const SizedBox(height: 8),
              const Text(
                'Значения имитации не приходят с очков.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilledDisc extends StatelessWidget {
  const _FilledDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x332F7BFF),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  if (hour < 23) return 'Добрый вечер';
  return 'Доброй ночи';
}

class _ConnectionCopy {
  const _ConnectionCopy({
    required this.title,
    required this.semantics,
    required this.hint,
  });

  final String title;
  final String semantics;
  final String hint;
}

_ConnectionCopy _connectionLabel(ConnectionStatus status) {
  return switch (status) {
    ConnectionStatus.connecting => const _ConnectionCopy(
      title: 'Подключение...',
      semantics: 'Подключение очков',
      hint: 'Подождите',
    ),
    ConnectionStatus.reconnecting => const _ConnectionCopy(
      title: 'Повторное подключение...',
      semantics: 'Повторное подключение очков',
      hint: 'Подождите',
    ),
    ConnectionStatus.connected => const _ConnectionCopy(
      title: 'Очки подключены',
      semantics: 'Очки подключены',
      hint: 'Двойное нажатие, чтобы отключить очки',
    ),
    ConnectionStatus.error => const _ConnectionCopy(
      title: 'Ошибка подключения',
      semantics: 'Ошибка подключения очков',
      hint: 'Двойное нажатие, чтобы повторить',
    ),
    ConnectionStatus.disconnected => const _ConnectionCopy(
      title: 'Очки не подключены',
      semantics: 'Подключить очки',
      hint: 'Двойное нажатие, чтобы подключить очки',
    ),
  };
}

bool _actionOn(String name) {
  return name == 'capturing' ||
      name == 'uploading' ||
      name == 'processing' ||
      name == 'success';
}

String pipelineLabel(VisionState vision, OcrState ocr) {
  if (ocr.status != OcrStatus.idle) return _statusLabel(ocr.status.name);
  return _statusLabel(vision.status.name);
}

String _statusLabel(String name) {
  return switch (name) {
    'capturing' => 'Захват изображения...',
    'uploading' => 'Отправка...',
    'processing' => 'Анализ...',
    'success' => 'Готово',
    'error' => 'Ошибка',
    _ => 'Готово',
  };
}

String? resultLabel(VisionState vision, OcrState ocr) {
  if (ocr.status == OcrStatus.error) return ocr.errorMessage;
  if (vision.status == VisionStatus.error && ocr.status == OcrStatus.idle) {
    return vision.errorMessage;
  }
  if (ocr.status == OcrStatus.success) return ocr.text;
  if (vision.status == VisionStatus.success) return vision.text;
  return null;
}
