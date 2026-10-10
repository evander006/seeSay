import 'package:equatable/equatable.dart';

enum ResponseType { scene, ocr }

class SavedResponse extends Equatable {
  const SavedResponse({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final ResponseType type;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'type': type.name,
    };
  }

  factory SavedResponse.fromJson(Map<String, dynamic> json) {
    return SavedResponse(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: json['type'] == ResponseType.ocr.name
          ? ResponseType.ocr
          : ResponseType.scene,
    );
  }

  @override
  List<Object?> get props => [id, text, createdAt, type];
}

abstract final class ResponseHistory {
  static const maxItems = 10;

  static List<SavedResponse> add(
    List<SavedResponse> current,
    SavedResponse response,
  ) {
    final next = [response, ...current.where((item) => item.id != response.id)];
    if (next.length <= maxItems) return next;
    return next.sublist(0, maxItems);
  }
}
