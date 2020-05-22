import 'package:flutter_test/flutter_test.dart';
import 'package:qiscus_chat_sdk/qiscus_chat_sdk.dart';

void main() {
  test('QiscusSDK::setup', () async {
    var qiscus = QiscusSDK();
    await qiscus.setup$('sdksample');
    expect(qiscus.appId, 'sdksample');
  });

  test('QiscusSDK::setupWithCustomServer', () async {});
}
