import 'package:equatable/equatable.dart';

enum ResponseType { scene, ocr }

class SavedResponse extends Equatable {
  const SavedResponse({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.type,
    this.prompt,
    this.imagePath,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final ResponseType type;

  /// What the user asked in the chat; null for the glasses button and quick actions.
  final String? prompt;

  /// The frame sent to the server, kept for the gallery.
  final String? imagePath;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'type': type.name,
      if (prompt != null) 'prompt': prompt,
      if (imagePath != null) 'imagePath': imagePath,
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
      prompt: json['prompt'] as String?,
      imagePath: json['imagePath'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, text, createdAt, type, prompt, imagePath];
}

abstract final class ResponseHistory {
  static const maxItems = 50;

  static List<SavedResponse> add(
    List<SavedResponse> current,
    SavedResponse response,
  ) {
    final next = [response, ...current.where((item) => item.id != response.id)];
    if (next.length <= maxItems) return next;
    return next.sublist(0, maxItems);
  }
}
