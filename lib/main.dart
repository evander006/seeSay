import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seesay/app/app.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait is fixed in AndroidManifest: this engine may start without a screen,
  // and platform calls that need an Activity would never answer.
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
