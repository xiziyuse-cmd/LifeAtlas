import 'package:flutter/material.dart';

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
  String? _version, _contentError, _error;
  bool _loading = true, _sending = false, _ready = false, _success = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _ready = false;
      _error = null;
    });
    try {
      final version = await _service.loadVersion();
      final pending = await _service.loadPending();
      if (!mounted) return;
      setState(() {
        _version = version;
        _ready = true;
        if (pending != null) {
          _subject.text = pending.subject;
          _content.text = pending.content;
          _contact.text = pending.contact;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '版本或草稿读取失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_ready || _sending) return;
    if (_content.text.trim().isEmpty) {
      setState(() => _contentError = '请填写反馈内容');
      _contentFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _success = false;
      _contentError = null;
    });
    try {
      await _service.submit(
        DeveloperFeedback(
          content: _content.text,
          version: _version!,
          subject: _subject.text,
          contact: _contact.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _subject.clear();
        _content.clear();
        _contact.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FeedbackSubmissionException
              ? e.message
              : '提交未确认，内容已保留，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
              const Text('反馈将直接提交给开发者，并附上软件版本。联系方式选填，方便回复。'),
              const SizedBox(height: 24),
              TextField(
                controller: _subject,
                enabled: _ready && !_sending,
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
                enabled: _ready && !_sending,
                focusNode: _contentFocus,
                minLines: 5,
                maxLines: 10,
                maxLength: 4000,
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
                enabled: _ready && !_sending,
                textInputAction: TextInputAction.done,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: '联系方式（选填）',
                  hintText: '方便回复你的邮箱或其他联系方式',
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (_success) ...[
                const Text('反馈已提交，感谢你的建议。', key: ValueKey('feedback-success')),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _ready && !_sending ? _send : null,
                icon: const Icon(Icons.send_outlined),
                label: Text(_sending ? '正在提交…' : '提交反馈'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Text('正在读取版本和草稿…')
                : !_ready
                ? TextButton(onPressed: _load, child: const Text('读取失败，点击重试'))
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
