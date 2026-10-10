import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seesay/app/app_messenger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/glasses/presentation/connection_cubit.dart';
import 'package:seesay/features/ocr/presentation/ocr_cubit.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

class FailureToaster extends StatelessWidget {
  const FailureToaster({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ConnectionCubit, ConnectionViewState>(
          listenWhen: (previous, next) =>
              next.status == ConnectionStatus.error &&
              next.message != null &&
              (previous.status != next.status ||
                  previous.message != next.message),
          listener: (context, state) => showAppMessage(state.message!),
        ),
        BlocListener<VisionCubit, VisionState>(
          listenWhen: (previous, next) =>
              next.status == VisionStatus.error &&
              next.errorMessage != null &&
              (previous.status != next.status ||
                  previous.errorMessage != next.errorMessage),
          listener: (context, state) => showAppMessage(state.errorMessage!),
        ),
        BlocListener<OcrCubit, OcrState>(
          listenWhen: (previous, next) =>
              next.status == OcrStatus.error &&
              next.errorMessage != null &&
              (previous.status != next.status ||
                  previous.errorMessage != next.errorMessage),
          listener: (context, state) => showAppMessage(state.errorMessage!),
        ),
      ],
      child: child,
    );
  }
}
