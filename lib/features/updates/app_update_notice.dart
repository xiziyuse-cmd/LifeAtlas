import 'package:flutter/foundation.dart';
import 'app_update_service.dart';

/// Shares a successful availability check between automatic notices and the
/// manual update page. Viewing/downloading is not proof of installation.
class AppUpdateNotice extends ChangeNotifier {
  AppUpdateNotice({AppUpdateService? service, bool? supported})
    : _service = service ?? AppUpdateService(),
      _supported = supported ?? AppUpdateService.supported;
  final AppUpdateService _service;
  final bool _supported;
  AppRelease? _available;
  AppRelease? get available => _available;
  bool get hasMinorUpdate => _available != null && !_available!.isMajorRelease;
  Future<void>? _checking;
  int _epoch = 0;
  bool _disposed = false;

  Future<void> check() {
    if (_disposed || !_supported) return Future.value();
    return _checking ??= _read().whenComplete(() => _checking = null);
  }

  Future<void> _read() async {
    final epoch = ++_epoch;
    try {
      final release = await _service.check();
      final info = await _service.deviceInfo();
      if (!_disposed && epoch == _epoch) {
        observe(
          release,
          currentBuild: info['build'] as int,
          sdk: info['sdk'] as int,
        );
      }
    } catch (_) {
      // A failed check neither invents an update nor dismisses a known one.
    }
  }

  void observe(
    AppRelease? release, {
    required int currentBuild,
    required int sdk,
  }) {
    if (_disposed) return;
    ++_epoch; // A manual result supersedes an older automatic request.
    _available =
        release != null &&
            release.isNewerThan(currentBuild) &&
            release.minSdk <= sdk
        ? release
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _service.close();
    super.dispose();
  }
}
