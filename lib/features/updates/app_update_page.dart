import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_update_service.dart';

class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key, this.initialRelease});
  final AppRelease? initialRelease;
  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  final _service = AppUpdateService();
  AppRelease? _release;
  File? _apk;
  bool _busy = false;
  double? _progress;
  String _message = '', _current = '读取中';
  int _build = 0, _sdk = 0;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!AppUpdateService.supported) {
      setState(() => _message = '当前平台暂不支持应用内安装更新');
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await _service.deviceInfo();
      if (!mounted) return;
      _build = info['build'] as int;
      _sdk = info['sdk'] as int;
      setState(() => _current = '${info['version']}（$_build）');
      if (widget.initialRelease != null) {
        setState(() => _release = widget.initialRelease);
      } else {
        await _check();
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _error(Object e) => e is PlatformException
      ? e.message ?? '安装校验失败'
      : e is UpdateCancelled
      ? '下载已取消，可重新下载'
      : e is SocketException
      ? '网络连接失败，请重试'
      : e is FormatException
      ? e.message
      : e.toString().replaceFirst('Bad state: ', '');
  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final release = await _service.check();
      if (!mounted) return;
      setState(() {
        _release = release;
        _apk = null;
        _progress = null;
        _message = release == null
            ? '暂时没有发布可用更新'
            : !release.isNewerThan(_build)
            ? '当前已是最新版本'
            : release.minSdk > _sdk
            ? '此版本需要更高的 Android 系统，暂时无法安装'
            : '';
      });
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final release = _release;
    if (release == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _message = '';
    });
    try {
      final file = await _service.download(release, (a, b) {
        if (mounted) setState(() => _progress = a / b);
      });
      if (mounted)
        setState(() {
          _apk = file;
          _message = '安装包校验通过，可以开始安装';
        });
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    if (_apk == null || _release == null) return;
    setState(() => _busy = true);
    try {
      final status = await _service.install(_apk!, _release!);
      if (mounted)
        setState(
          () => _message = status == 'permissionRequired'
              ? '请在系统页面允许 LifeAtlas 安装应用，返回后再次点击“安装更新”。'
              : '已打开系统安装页面，请确认安装；取消后可以重试。',
        );
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    final available =
        release != null &&
        release.isNewerThan(_build) &&
        release.minSdk <= _sdk;
    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.system_update_outlined, size: 56),
          const SizedBox(height: 18),
          Text(
            'LifeAtlas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('当前版本：$_current', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (release != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '版本 ${release.version}（${release.build}）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '安装包 ${(release.size / 1048576).toStringAsFixed(1)} MB',
                    ),
                    const SizedBox(height: 16),
                    Text(release.notes),
                  ],
                ),
              ),
            ),
          if (_progress != null) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress! * 100).round()}%${_busy && _progress == 1 ? ' · 正在校验安装包' : ''}',
            ),
          ],
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(_message),
            ),
          if (_busy && _progress == null)
            const Center(child: CircularProgressIndicator()),
          if (!_busy && AppUpdateService.supported) ...[
            const SizedBox(height: 18),
            if (available)
              FilledButton.icon(
                onPressed: _apk == null ? _download : _install,
                icon: Icon(
                  _apk == null ? Icons.download : Icons.install_mobile,
                ),
                label: Text(_apk == null ? '下载更新' : '安装更新'),
              ),
            TextButton(onPressed: _check, child: const Text('重新检查')),
          ],
          if (_busy && _progress != null)
            TextButton(onPressed: _service.cancel, child: const Text('取消下载')),
        ],
      ),
    );
  }
}

class AppUpdatePrompt {
  static Future<void> check(BuildContext context) async {
    if (!AppUpdateService.supported) return;
    final service = AppUpdateService();
    try {
      final info = await service.deviceInfo();
      final release = await service.check();
      if (!context.mounted ||
          release == null ||
          !release.isNewerThan(info['build'] as int) ||
          release.minSdk > (info['sdk'] as int))
        return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('发现新版本 ${release.version}'),
          content: SingleChildScrollView(
            child: Text(
              '${release.notes}\n\n安装包 ${(release.size / 1048576).toStringAsFixed(1)} MB',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('查看更新'),
            ),
          ],
        ),
      );
      if (accepted == true && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppUpdatePage(initialRelease: release),
          ),
        );
      }
    } catch (_) {
      /* Automatic checks never block launch; manual checks show errors. */
    } finally {
      service.close();
    }
  }
}
