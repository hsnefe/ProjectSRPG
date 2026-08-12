import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/main.dart';

void main() {
  test('fare ve trackpad ile sürükleyerek kaydırma açık', () {
    // Varsayılan davranış masaüstü ve web'de yalnızca dokunma ve kalemi tanır;
    // yatay şeritler bu yüzden hiç kaymıyordu. Widget testleri her zaman
    // dokunma olayı gönderdiği için bir tester.drag bunu yakalayamaz — nöbeti
    // bu test tutuyor.
    const behavior = AppScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));
  });
}
