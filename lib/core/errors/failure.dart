import 'package:equatable/equatable.dart';
import 'package:seesay/core/errors/app_exception.dart';

class Failure extends Equatable {
  const Failure({required this.message, required this.cause});

  final String message;
  final AppException cause;

  @override
  List<Object?> get props => [message, cause.runtimeType];
}
