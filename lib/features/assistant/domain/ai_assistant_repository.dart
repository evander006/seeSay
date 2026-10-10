class AssistantReply {
  const AssistantReply({required this.text, required this.simulated});

  final String text;
  final bool simulated;
}

abstract class AiAssistantRepository {
  Future<AssistantReply> reply(String prompt);
}

class MockAiAssistantRepository implements AiAssistantRepository {
  const MockAiAssistantRepository();

  @override
  Future<AssistantReply> reply(String prompt) async {
    final trimmed = prompt.trim();
    return AssistantReply(
      text: 'Демонстрационный ответ. Вы написали: $trimmed',
      simulated: true,
    );
  }
}
