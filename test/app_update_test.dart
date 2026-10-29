import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/updates/app_update_service.dart';

void main() {
  final endpoint = Uri.parse(
    'https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest',
  );
  Map<String, dynamic> manifest() => {
    'release': {
      'version': '2.1.0',
      'build': 28,
      'notes': '更新说明',
      'size': 1024,
      'sha256': 'a' * 64,
      'minSdk': 24,
      'packageName': 'com.example.lifeatlas',
      'url': '$endpoint?download=1&id=example',
    },
  };
  test(
    'uses numeric build ordering and accepts only the expected package and HTTPS origin',
    () {
      final release = AppRelease.parse(manifest(), endpoint)!;
      expect(release.isNewerThan(27), isTrue);
      expect(release.isNewerThan(28), isFalse);
      expect(release.isNewerThan(100), isFalse);
      for (final patch in [
        {'packageName': 'evil.app'},
        {'url': 'https://other.test/v1/update/latest?download=1'},
        {
          'url':
              'http://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest?download=1',
        },
        {'sha256': 'bad'},
        {'size': 999999999},
      ]) {
        final input = manifest();
        (input['release'] as Map).addAll(patch);
        expect(() => AppRelease.parse(input, endpoint), throwsFormatException);
      }
    },
  );
  test(
    'no active release is a valid empty response and malformed metadata is rejected',
    () {
      expect(AppRelease.parse({'release': null}, endpoint), isNull);
      expect(
        () => AppRelease.parse({'release': []}, endpoint),
        throwsFormatException,
      );
    },
  );
}
