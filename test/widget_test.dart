import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/models/models.dart';

void main() {
  test('parses synced LRC lyrics', () {
    final lines = Lyrics.parseLrc('[00:01.50] Hello\n[00:03.00][00:10.00] Again');
    expect(lines.length, 3);
    expect(lines.first.time, const Duration(milliseconds: 1500));
    expect(lines.last.text, 'Again');
  });
}
