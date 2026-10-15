import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/app_messenger.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/app/theme/ui.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/core/platform/background_access.dart';
import 'package:seesay/features/backend/backend_cubit.dart';
import 'package:seesay/features/glasses/presentation/glasses_action_coordinator.dart';
import 'package:seesay/features/settings/presentation/accessibility_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.background,
    required this.onOpenSystemSettings,
    this.standalone = false,
    super.key,
  });

  final BackgroundAccess background;
  final Future<void> Function() onOpenSystemSettings;

  /// Opened on top of the tabs (from the server row), so it needs a back button.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: standalone,
        child: ListView(
          padding: Gaps.page,
          children: [
            PageTitle(
              title: 'Настройки',
              trailing: [
                if (standalone)
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Закрыть настройки',
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
              ],
            ),
            const _ServerSection(),
            Gaps.between,
            _BackgroundSection(background: background),
            Gaps.between,
            const _SpeechSection(),
            Gaps.between,
            const _DemoSection(),
            Gaps.between,
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _LinkRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Разрешения приложения',
                    subtitle: 'Bluetooth, камера, уведомления',
                    onTap: onOpenSystemSettings,
                  ),
                  const Divider(height: 1, indent: 56),
                  const _LinkRow(
                    icon: Icons.info_outline_rounded,
                    title: 'SeeSay 3.2 (демо AI ATOM)',
                    subtitle: 'Умные очки AIMB S2 MAX',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSection extends StatefulWidget {
  const _ServerSection();

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  late final TextEditingController _input;
  String? _result;
  bool? _resultOk;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: context.read<BackendCubit>().state.url);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    final result = await context.read<BackendCubit>().apply(_input.text);
    if (!mounted) return;
    setState(() {
      _result = result.message;
      _resultOk = result.ok;
    });
    if (result.ok) {
      _input.text = context.read<BackendCubit>().state.url;
    }
    showAppMessage(result.ok ? 'Сервер подключён' : 'Сервер не подключён');
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendCubit>().state;
    final checking = backend.status == BackendStatus.checking;
    final (color, label) = switch (backend.status) {
      BackendStatus.online => (AppColors.ok, 'На связи'),
      BackendStatus.offline => (AppColors.danger, 'Нет связи'),
      BackendStatus.checking => (AppColors.warning, 'Проверяю…'),
      BackendStatus.unknown => (AppColors.muted, 'Не проверен'),
    };
    return BlocListener<BackendCubit, BackendState>(
      listenWhen: (previous, next) => previous.url != next.url,
      listener: (context, state) {
        if (_input.text.trim().isEmpty) _input.text = state.url;
      },
      child: SectionCard(
      title: 'Сервер',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Куда приложение отправляет снимки. Адрес и порт сервера:',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusDot(color: color, size: 8),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  backend.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_apply()),
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              hintText: '192.168.0.128:8000',
              filled: true,
              fillColor: AppColors.circle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Можно без http://. Для сервера в интернете укажите https://адрес.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            id: 'server-apply',
            label: checking ? 'Проверяю…' : 'Проверить и сохранить',
            icon: Icons.wifi_tethering_rounded,
            busy: checking,
            onTap: () => unawaited(_apply()),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _Notice(ok: _resultOk ?? false, text: _result!),
          ] else if (backend.status == BackendStatus.offline && backend.message != null) ...[
            const SizedBox(height: 12),
            _Notice(ok: false, text: backend.message!),
          ],
        ],
      ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.ok : AppColors.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundSection extends StatefulWidget {
  const _BackgroundSection({required this.background});

  final BackgroundAccess background;

  @override
  State<_BackgroundSection> createState() => _BackgroundSectionState();
}

class _BackgroundSectionState extends State<_BackgroundSection>
    with WidgetsBindingObserver {
  bool? _unrestricted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user returns from the system dialog: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final value = await widget.background.isUnrestricted();
    if (mounted) setState(() => _unrestricted = value);
  }

  @override
  Widget build(BuildContext context) {
    final free = _unrestricted ?? false;
    return SectionCard(
      title: 'Работа в фоне',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusDot(color: free ? AppColors.ok : AppColors.warning, size: 8),
              const SizedBox(width: 8),
              Text(
                _unrestricted == null
                    ? 'Проверяю…'
                    : free
                    ? 'Разрешена без ограничений'
                    : 'Ограничена экономией батареи',
                style: TextStyle(
                  color: free ? AppColors.ok : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Очки отвечают, даже когда SeeSay свёрнут, экран выключен или приложение смахнуто из недавних, пока очки подключены.',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.35),
          ),
          if (!free) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              id: 'background-allow',
              label: 'Разрешить работу в фоне',
              icon: Icons.battery_charging_full_rounded,
              onTap: () async {
                await widget.background.request();
                await _refresh();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeechSection extends StatelessWidget {
  const _SpeechSection();

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessibilityCubit>().state;
    return SectionCard(
      title: 'Речь',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Скорость', style: TextStyle(fontSize: 16))),
              Text(
                '×${access.speechRate.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: access.speechRate,
            min: 0.5,
            max: 2,
            divisions: 15,
            label: access.speechRate.toStringAsFixed(1),
            semanticFormatterCallback: (value) =>
                'Скорость речи ${value.toStringAsFixed(1)}',
            onChanged: (value) => unawaited(
              context.read<AccessibilityCubit>().setSpeechRate(value),
            ),
          ),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: const Color(0xFFDCE8FF),
              selectedForegroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: Color(0xFFE1E4EA)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              minimumSize: const Size.fromHeight(46),
            ),
            segments: const [
              ButtonSegment(value: 'ru-RU', label: Text('Русский')),
              ButtonSegment(value: 'en-US', label: Text('English')),
            ],
            selected: {access.language},
            onSelectionChanged: (value) => unawaited(
              context.read<AccessibilityCubit>().setLanguage(value.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rehearsal and diagnostics: the same actions as the glasses buttons, plus the log upload.
class _DemoSection extends StatelessWidget {
  const _DemoSection();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<GlassesActionCoordinator>()) {
      return const SizedBox.shrink();
    }
    final coordinator = getIt<GlassesActionCoordinator>();
    Future<void> run(Future<String> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final text = await action();
        messenger.showSnackBar(SnackBar(content: Text(text)));
      } on Object catch (error) {
        messenger.showSnackBar(SnackBar(content: Text('Ошибка: $error')));
      }
    }

    return SectionCard(
      title: 'Демо и диагностика',
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _LinkRow(
            icon: Icons.campaign_outlined,
            title: 'Рассказ про конкурентов',
            subtitle: 'На очках: красная кнопка 3 раза за 3 секунды',
            onTap: () => run(() async {
              await coordinator.playPitch(reason: 'settings');
              return 'Рассказ закончен';
            }),
          ),
          const Divider(height: 1, indent: 56),
          _LinkRow(
            icon: Icons.photo_camera_outlined,
            title: 'Снимок с очков',
            subtitle: 'На очках: чёрная кнопка 2 раза',
            onTap: () => run(() async {
              final ok = await coordinator.requestFrame();
              return ok ? 'Очки снимают, ответ прозвучит в очках' : 'Очки не подключены';
            }),
          ),
          const Divider(height: 1, indent: 56),
          _LinkRow(
            icon: Icons.stop_circle_outlined,
            title: 'Остановить речь',
            subtitle: 'На очках: касание дужки',
            onTap: () => run(() async {
              await coordinator.stopAll();
              return 'Остановлено';
            }),
          ),
          const Divider(height: 1, indent: 56),
          _LinkRow(
            icon: Icons.bug_report_outlined,
            title: 'Отправить журнал на сервер',
            subtitle: 'Все пакеты очков, ответы сервера и ошибки',
            onTap: () => run(() async => 'Журнал отправлен: ${await coordinator.uploadLog()}'),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap == null ? null : () => unawaited(onTap!()),
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}
