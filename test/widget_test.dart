import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/config/dotenv.dart';

void main() {
  test('dotenv skips comments and blank lines', () {
    final values = DotEnv.parse('''
# comment
API_BASE_URL=http://10.0.2.2:8000
USE_MOCK_GLASSES=true

''');
    expect(values['API_BASE_URL'], 'http://10.0.2.2:8000');
    expect(values['USE_MOCK_GLASSES'], 'true');
  });
}
