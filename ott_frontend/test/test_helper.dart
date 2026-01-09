import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// PUBLIC_INTERFACE
void initSqfliteFfiForTests() {
  /// Initialize sqflite to use the FFI implementation for unit/widget tests.
  /// This prevents tests from hanging when a platform implementation is not
  /// available (e.g., in `flutter test` on CI).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
