import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/developer_contact_service.dart';

class ContactDeveloperPage extends StatefulWidget {
  const ContactDeveloperPage({super.key, this.service});
  final DeveloperContactService? service;
  @override
  State<ContactDeveloperPage> createState() => _ContactDeveloperPageState();
}

class _ContactDeveloperPageState extends State<ContactDeveloperPage> {
  late final _service = widget.service ?? DeveloperContactService();
  final _subject = TextEditingController();
  final _content = TextEditingController();
  final _contact = TextEditingController();
  final _contentFocus = FocusNode();
  String? _version;
  String? _contentError;
  bool _loading = true;
  bool _sending = false;
  String? _mailError;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    setState(() => _loading = true);
    try {
      final version = await _service.loadVersion();
      if (mounted) setState(() => _version = version);
    } catch (_) {
      if (mounted) setState(() => _version = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DeveloperFeedback? _feedback() {
    if (_version == null) return null;
    if (_content.text.trim().isEmpty) {
      setState(() => _contentError = '请填写反馈内容');
      _contentFocus.requestFocus();
      return null;
    }
    setState(() => _contentError = null);
    return DeveloperFeedback(
      content: _content.text,
      version: _version!,
      subject: _subject.text,
      contact: _contact.text,
    );
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final feedback = _feedback();
    if (feedback == null || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _mailError = null;
    });
    try {
      final opened = await _service.openMail(feedback);
      if (!mounted) return;
      if (opened) {
        _notice('已打开邮箱，请在邮箱中确认发送');
      } else {
        setState(() => _mailError = '未能打开邮箱，请安装并登录邮箱 App，或复制反馈后自行发送。');
      }
    } catch (_) {
      if (mounted) setState(() => _mailError = '打开邮箱失败，可重试或复制反馈后自行发送。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy() async {
    final feedback = _feedback();
    if (feedback == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: feedback.copyText));
      if (mounted) _notice('已复制收件人、反馈内容和版本号');
    } catch (_) {
      if (mounted) _notice('复制失败，请重试');
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _content.dispose();
    _contact.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('联系开发者')),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('告诉我你的想法', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const SelectableText(developerEmail),
              const SizedBox(height: 8),
              const Text('反馈会通过手机邮箱发送，自动附上软件版本。打开邮箱后确认发送即可。'),
              const SizedBox(height: 24),
              TextField(
                controller: _subject,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '主题（选填）',
                  hintText: '问题反馈或功能建议',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                focusNode: _contentFocus,
                minLines: 5,
                maxLines: 10,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '反馈内容',
                  hintText: '请描述遇到的问题或你的建议',
                  alignLabelWithHint: true,
                  errorText: _contentError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                textInputAction: TextInputAction.done,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: '联系方式（选填）',
                  hintText: '方便回复你的邮箱或其他联系方式',
                ),
              ),
              const SizedBox(height: 20),
              if (_mailError != null) ...[
                Text(
                  _mailError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _version == null || _sending ? null : _send,
                icon: const Icon(Icons.mail_outline),
                label: Text(_sending ? '正在打开邮箱…' : '发送邮件'),
              ),
              TextButton.icon(
                onPressed: _version == null || _sending ? null : _copy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制反馈内容'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Text('正在读取版本…')
                : _version == null
                ? TextButton(
                    onPressed: _loadVersion,
                    child: const Text('版本读取失败，点击重试'),
                  )
                : Text(
                    '当前版本：$_version',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ),
      ],
    ),
  );
}
