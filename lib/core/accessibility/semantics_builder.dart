String semanticsAnnouncement({required String label, required String hint}) {
  final hintText = hint.trim();
  if (hintText.isEmpty) return label.trim();
  final withPeriod = hintText.endsWith('.') ? hintText : '$hintText.';
  return '${label.trim()}. $withPeriod';
}
