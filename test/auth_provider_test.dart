import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passportvault/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pv_user': 'Test User,test@example.com',
      'pv_cached_documents': '[{"id":"document-1"}]',
      'pv_pending_sync_queue':
          '[{"type":"edit_document","data":{"id":"document-1"}}]',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'logout is blocked and preserves local data while edits are queued',
    () async {
      final provider = AuthProvider();
      final didLogout = await provider.logout();
      final prefs = await SharedPreferences.getInstance();

      expect(didLogout, isFalse);
      expect(provider.errorMessage, contains('1 unsynced offline change'));
      expect(prefs.getString('pv_user'), 'Test User,test@example.com');
      expect(prefs.getString('pv_cached_documents'), '[{"id":"document-1"}]');
      expect(prefs.getString('pv_pending_sync_queue'), isNotEmpty);

      provider.dispose();
    },
  );

  test(
    'logout is blocked when the pending queue cannot be read safely',
    () async {
      SharedPreferences.setMockInitialValues({
        'pv_user': 'Test User,test@example.com',
        'pv_pending_sync_queue': '{invalid json',
      });

      final provider = AuthProvider();
      final didLogout = await provider.logout();
      final prefs = await SharedPreferences.getInstance();

      expect(didLogout, isFalse);
      expect(
        provider.errorMessage,
        contains('Unable to verify pending offline changes'),
      );
      expect(prefs.getString('pv_user'), 'Test User,test@example.com');
      expect(prefs.getString('pv_pending_sync_queue'), '{invalid json');

      provider.dispose();
    },
  );
}
