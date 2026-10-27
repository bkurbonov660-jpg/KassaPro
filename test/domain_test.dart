import 'package:flutter_test/flutter_test.dart';
import 'package:aegisroot/models.dart';
import 'package:aegisroot/theme.dart';

void main() {
  test('fmtDurationMs formats hours, minutes and seconds accurately', () {
    expect(fmtDurationMs(0, showSeconds: true), '00:00:00');
    expect(fmtDurationMs(3661000, showSeconds: true), '01:01:01');
    expect(fmtDurationMs(3600000), '1 ч');
  });

  test('AppUsageItem parses boundary map and computes totalBytes', () {
    final item = AppUsageItem.fromMap({
      'pkg': 'org.telegram.messenger',
      'name': 'Telegram',
      'uid': 10145,
      'usageMs': 120000,
      'mobileBytes': 1024,
      'wifiBytes': 2048,
      'isSystem': false,
      'isFrozen': false,
      'isNetBlocked': true,
      'dailyLimitMinutes': 60,
    });
    expect(item.totalBytes, 3072);
    expect(item.isNetBlocked, true);
    expect(item.dailyLimitMinutes, 60);
  });
}
