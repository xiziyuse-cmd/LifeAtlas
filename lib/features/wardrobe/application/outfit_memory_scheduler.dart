import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/wardrobe_repository.dart';

/// Performs the in-process 22:00 outfit-temperature sync and catch-up runs.
///
/// Mobile operating systems do not guarantee an exact background wake-up when
/// the app is terminated. Pending dates are therefore also synchronized every
/// time the app starts or returns to the foreground.
class OutfitMemoryScheduler with WidgetsBindingObserver {
  OutfitMemoryScheduler(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WardrobeRepository _repository;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await _syncPending();
    _scheduleNextRun();
  }

  void dispose() {
    if (!_started) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPending());
      _scheduleNextRun();
    }
  }

  Future<void> _syncPending() async {
    try {
      await _repository.syncPendingTemperatureMemory();
    } on Object {
      // A later resume/start run retries. The scheduler must not terminate the
      // app when weather data or the local database is temporarily unavailable.
    }
  }

  void _scheduleNextRun() {
    _timer?.cancel();
    final now = _clock();
    var nextRun = DateTime(now.year, now.month, now.day, 22);
    if (!nextRun.isAfter(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }
    _timer = Timer(nextRun.difference(now), () async {
      await _syncPending();
      if (_started) {
        _scheduleNextRun();
      }
    });
  }
}
