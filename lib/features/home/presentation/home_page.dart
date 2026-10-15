import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/app/theme/ui.dart';
import 'package:seesay/core/accessibility/touch_exploration_scope.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/backend/backend_cubit.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/home/presentation/glasses_artwork.dart';
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
          child: ListView(
            padding: Gaps.page,
            children: [
              PageTitle(title: 'SeeSay', subtitle: _greeting()),
              const _GlassesCard(),
              Gaps.between,
              const _ActionsCard(),
              Gaps.between,
              const _ResultCard(),
              Gaps.between,
              const _ServerRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassesCard extends StatelessWidget {
  const _GlassesCard();

  @override
  Widget build(BuildContext context) {
    final link = context.watch<ConnectionCubit>().state;
    final copy = _connectionLabel(link.status);
    final connected = link.status == ConnectionStatus.connected;
    final busy = link.status == ConnectionStatus.connecting ||
        link.status == ConnectionStatus.reconnecting;
    final failed = link.status == ConnectionStatus.error;
    final dot = connected
        ? AppColors.ok
        : failed
        ? AppColors.danger
        : busy
        ? AppColors.warning
        : AppColors.muted;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) => GlassesArtwork(
                width: constraints.maxWidth * 0.8,
                dimmed: !connected,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusDot(color: dot),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  copy.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (connected && link.battery != null)
                _Chip(
                  icon: Icons.battery_full_rounded,
                  label: '${link.battery}%',
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: link.detail != null && !connected
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 20),
                    child: Text(
                      link.detail!,
                      style: TextStyle(
                        color: failed ? AppColors.danger : AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            id: 'connection',
            label: connected
                ? 'Отключить очки'
                : busy
                ? 'Подключаю…'
                : failed
                ? 'Попробовать снова'
                : 'Подключить очки',
            hint: copy.hint,
            icon: connected ? Icons.link_off_rounded : Icons.bluetooth_rounded,
            busy: busy,
            tone: connected ? ButtonTone.quiet : ButtonTone.accent,
            onTap: () => unawaited(_toggle(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final cubit = context.read<ConnectionCubit>();
    if (cubit.state.status == ConnectionStatus.connected) {
      await cubit.disconnect();
      return;
    }
    await cubit.connect();
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard();

  @override
  Widget build(BuildContext context) {
    final vision = context.watch<VisionCubit>().state;
    final ocr = context.watch<OcrCubit>().state;
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                icon: Icons.visibility_outlined,
                title: 'Что вокруг',
                caption: 'Описать сцену',
                filled: _working(vision.status.name),
                fillColor: AppColors.accent,
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
                icon: Icons.text_snippet_outlined,
                title: 'Текст',
                caption: 'Прочитать',
                filled: _working(ocr.status.name),
                fillColor: const Color(0xFF5B6CFF),
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
                icon: Icons.replay_rounded,
                title: 'Повтор',
                caption: 'Последний ответ',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard();

  @override
  Widget build(BuildContext context) {
    final vision = context.watch<VisionCubit>().state;
    final ocr = context.watch<OcrCubit>().state;
    final result = resultLabel(vision, ocr);
    final working = _working(vision.status.name) || _working(ocr.status.name);
    final failed =
        vision.status == VisionStatus.error || ocr.status == OcrStatus.error;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (working)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: failed ? AppColors.danger : AppColors.muted,
                  ),
                ),
              Text(
                pipelineLabel(vision, ocr),
                style: TextStyle(
                  color: failed ? AppColors.danger : AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result ??
                (working
                    ? 'Снимок уходит на сервер, ответ прозвучит в очках.'
                    : 'Нажмите кнопку на дужке очков или «Что вокруг». Ответ появится здесь и прозвучит в очках.'),
            style: TextStyle(
              fontSize: result == null ? 15 : 17,
              height: 1.4,
              color: result == null ? AppColors.muted : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow();

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendCubit>().state;
    final (color, label) = switch (backend.status) {
      BackendStatus.online => (AppColors.ok, 'на связи'),
      BackendStatus.offline => (AppColors.danger, 'нет связи'),
      BackendStatus.checking => (AppColors.warning, 'проверяю…'),
      BackendStatus.unknown => (AppColors.muted, 'не проверен'),
    };
    final host = Uri.tryParse(backend.url)?.authority ?? backend.url;
    return AccessibleAction(
      id: 'server',
      label: 'Сервер $host, $label',
      hint: 'Двойное нажатие, чтобы открыть настройки сервера',
      onTap: () => context.push('/settings'),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.dns_outlined, color: AppColors.ink, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сервер',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    host.isEmpty ? 'не указан' : host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            StatusDot(color: color, size: 8),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.circle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.ok),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 5) return 'Доброй ночи';
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  if (hour < 23) return 'Добрый вечер';
  return 'Доброй ночи';
}

class _ConnectionCopy {
  const _ConnectionCopy({required this.title, required this.hint});

  final String title;
  final String hint;
}

_ConnectionCopy _connectionLabel(ConnectionStatus status) {
  return switch (status) {
    ConnectionStatus.connecting => const _ConnectionCopy(
      title: 'Подключение…',
      hint: 'Подождите',
    ),
    ConnectionStatus.reconnecting => const _ConnectionCopy(
      title: 'Повторное подключение…',
      hint: 'Подождите',
    ),
    ConnectionStatus.connected => const _ConnectionCopy(
      title: 'Очки подключены',
      hint: 'Двойное нажатие, чтобы отключить очки',
    ),
    ConnectionStatus.error => const _ConnectionCopy(
      title: 'Ошибка подключения',
      hint: 'Двойное нажатие, чтобы повторить',
    ),
    ConnectionStatus.disconnected => const _ConnectionCopy(
      title: 'Очки не подключены',
      hint: 'Двойное нажатие, чтобы подключить очки',
    ),
  };
}

bool _working(String name) =>
    name == 'capturing' || name == 'uploading' || name == 'processing';

String pipelineLabel(VisionState vision, OcrState ocr) {
  if (ocr.status != OcrStatus.idle) return _statusLabel(ocr.status.name);
  return _statusLabel(vision.status.name);
}

String _statusLabel(String name) {
  return switch (name) {
    'capturing' => 'Делаю снимок…',
    'uploading' => 'Отправляю на сервер…',
    'processing' => 'Сервер думает…',
    'error' => 'Ошибка',
    _ => 'Последний ответ',
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
