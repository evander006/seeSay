import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/app_messenger.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/app/theme/screen_header.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AssistantCubit>().state;
    return BlocListener<AssistantCubit, AssistantState>(
      listenWhen: (previous, next) =>
          next.error != null && next.error != previous.error,
      listener: (context, state) => showAppMessage(state.error!),
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              subtitle: 'Помощник',
              title: 'AI-помощник',
              trailing: [
                CircleIconButton(
                  tooltip: 'Повторить ответ',
                  icon: Icons.replay_rounded,
                  onTap: () => context.read<AssistantCubit>().repeat(),
                ),
                CircleIconButton(
                  tooltip: 'Остановить речь',
                  icon: Icons.stop_circle_outlined,
                  onTap: () => context.read<AssistantCubit>().stop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Quick(
                          icon: Icons.videocam_outlined,
                          title: 'Опиши, что вокруг',
                          caption: 'Сцена',
                          enabled: !state.loading,
                          onTap: () =>
                              context.read<AssistantCubit>().describe(),
                        ),
                      ),
                      Expanded(
                        child: _Quick(
                          icon: Icons.tune_rounded,
                          title: 'Прочитай текст',
                          caption: 'Снимок',
                          enabled: !state.loading,
                          onTap: () =>
                              context.read<AssistantCubit>().readText(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(state.error!)),
                    TextButton(
                      onPressed: () => context.read<AssistantCubit>().retry(),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length + (state.loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.messages.length) {
                    return const ListTile(title: Text('Готовлю ответ...'));
                  }
                  final line = state.messages[index];
                  final time =
                      '${line.at.hour.toString().padLeft(2, '0')}:${line.at.minute.toString().padLeft(2, '0')}';
                  return Align(
                    alignment: line.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: line.fromUser
                            ? AppColors.accent
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.text,
                            style: TextStyle(
                              color: line.fromUser
                                  ? Colors.white
                                  : AppColors.ink,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.simulated ? '$time · имитация' : time,
                            style: TextStyle(
                              color: line.fromUser
                                  ? Colors.white70
                                  : AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: _input,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: _send,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.accent,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Отправить',
                        onPressed: () => _send(_input.text),
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _send(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _input.clear();
    context.read<AssistantCubit>().send(text);
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.title,
    required this.caption,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: RoundAction(icon: icon, title: title, caption: caption),
      ),
    );
  }
}
