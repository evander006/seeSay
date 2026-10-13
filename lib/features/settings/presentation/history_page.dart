import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/settings/presentation/history_cubit.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'История ответов',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: state.loading
                      ? const Center(
                          child: Text(
                            'Загрузка...',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                            ),
                          ),
                        )
                      : state.items.isEmpty
                      ? const Center(
                          child: Text(
                            'Нет сохранённых ответов.',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return SizedBox(
                              height: 120,
                              child: AccessibleAction(
                                id: 'history-${item.id}',
                                label: item.text,
                                hint: 'Двойное нажатие, чтобы прослушать',
                                onTap: () => unawaited(
                                  context.read<HistoryCubit>().speak(item),
                                ),
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: AppColors.accent),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        item.text,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(
                  height: 88,
                  child: AccessibleAction(
                    id: 'history-back',
                    label: 'Назад к настройкам',
                    hint: 'Двойное нажатие для активации',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    },
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.accent),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Назад',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
