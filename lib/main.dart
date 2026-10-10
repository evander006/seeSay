import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seesay/app/app.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await configureDependencies();
  final logger = getIt<AppLogger>();
  FlutterError.onError = (details) {
    logger.error('uncaught exception', error: details.exception);
  };
  try {
    await getIt<AppBootstrap>().start();
  } on Object catch (error) {
    logger.error('uncaught exception', error: error);
  }
  runApp(const SeeSayApp());
}
