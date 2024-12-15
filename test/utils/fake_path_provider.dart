import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter/services.dart';

class FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.dart_tool/sqflite_common_ffi/test';
  }

  @override
  Future<String?> getTemporaryPath() async {
    return '.dart_tool/sqflite_common_ffi/test';
  }

  @override
  Future<String?> getLibraryPath() async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getExternalStoragePath() async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getDownloadsPath() async {
    throw UnimplementedError();
  }
}
