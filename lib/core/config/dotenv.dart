abstract final class DotEnv {
  static Map<String, String> parse(String raw) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      var value = trimmed.substring(separator + 1).trim();
      if (value.length >= 2) {
        final quote = value[0];
        if ((quote == '"' || quote == "'") && value.endsWith(quote)) {
          value = value.substring(1, value.length - 1);
        }
      }
      values[key] = value;
    }
    return values;
  }
}
