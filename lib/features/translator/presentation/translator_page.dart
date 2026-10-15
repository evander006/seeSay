import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/ui.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/api_client.dart';
import 'package:seesay/features/translator/data/translator_api.dart';
import 'package:seesay/features/translator/data/translator_channel.dart';
import 'package:seesay/features/translator/presentation/translator_cubit.dart';

/// «Перевод» tab: live interpreter between the user (Russian) and a partner (any language).
class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranslatorCubit(
        channel: TranslatorChannel(),
        api: TranslatorApi(() => getIt<ApiClient>()),
        logger: getIt.isRegistered<AppLogger>() ? getIt<AppLogger>() : AppLogger(),
      ),
      child: const _TranslatorView(),
    );
  }
}

class _TranslatorView extends StatelessWidget {
  const _TranslatorView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<TranslatorCubit, TranslatorState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, state) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message!))),
          builder: (context, state) {
            final cubit = context.read<TranslatorCubit>();
            return Padding(
              padding: Gaps.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTitle(
                    title: 'Переводчик',
                    subtitle: 'Живой перевод разговора',
                    trailing: [
                      if (state.lines.isNotEmpty)
                        IconButton(
                          tooltip: 'Очистить разговор',
                          icon: const Icon(Icons.delete_sweep_outlined),
                          onPressed: cubit.clear,
                        ),
                    ],
                  ),
                  _Controls(state: state, cubit: cubit),
                  Gaps.between,
                  Expanded(child: _Conversation(state: state)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.cubit});

  final TranslatorState state;
  final TranslatorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final partner = state.partner == 'auto' && state.detected != null
        ? 'Собеседник: ${languageName(state.detected!)} (определён сам)'
        : 'Собеседник: ${languageName(state.partner == 'auto' ? 'en' : state.partner)}'
              '${state.partner == 'auto' ? ' — уточнится по первой фразе' : ''}';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: state.active ? AppColors.danger : AppColors.accent,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              onPressed: state.busy ? null : cubit.toggle,
              icon: Icon(state.active ? Icons.stop_rounded : Icons.translate_rounded),
              label: Text(state.active ? 'Остановить перевод' : 'Начать перевод'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                state.speaking ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                color: state.active ? AppColors.ok : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !state.active
                          ? 'Выключен'
                          : state.speaking
                          ? 'Слышу речь…'
                          : 'Слушаю разговор',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state.active ? state.level : 0,
                        minHeight: 6,
                        backgroundColor: AppColors.circle,
                        color: AppColors.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(partner, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
              DropdownButton<String>(
                value: state.partner,
                underline: const SizedBox.shrink(),
                onChanged: (code) => code == null ? null : cubit.setPartner(code),
                items: [
                  for (final entry in translatorLanguages.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Положите телефон между собеседниками. Речь собеседника звучит вам в очках по-русски, '
            'ваша — из динамика телефона на его языке.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.state});

  final TranslatorState state;

  @override
  Widget build(BuildContext context) {
    if (state.lines.isEmpty) {
      return const Center(
        child: Text(
          'Здесь появится разговор:\nоригинал и перевод каждой фразы.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    final lines = state.lines.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: lines.length,
      itemBuilder: (context, i) => _Bubble(line: lines[i]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.line});

  final TranslatorLine line;

  @override
  Widget build(BuildContext context) {
    final mine = line.fromUser;
    final Widget content;
    if (line.pending) {
      content = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Перевожу…', style: TextStyle(color: AppColors.muted)),
        ],
      );
    } else if (line.failed) {
      content = const Text('Не удалось перевести фразу', style: TextStyle(color: AppColors.danger));
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${mine ? 'Вы' : 'Собеседник'} · ${languageName(line.lang)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(line.original, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: 4),
          Text(line.translation, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDCE8FF) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }
}
