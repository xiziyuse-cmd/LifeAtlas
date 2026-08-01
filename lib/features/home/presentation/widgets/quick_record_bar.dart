import 'package:flutter/material.dart';

typedef QuickRecordSender = Future<bool> Function(String text);

class QuickRecordBar extends StatefulWidget {
  const QuickRecordBar({
    super.key,
    required this.onImagePressed,
    required this.onSend,
  });

  final VoidCallback onImagePressed;
  final QuickRecordSender onSend;

  @override
  State<QuickRecordBar> createState() => _QuickRecordBarState();
}

class _QuickRecordBarState extends State<QuickRecordBar> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入记录内容')));
      return;
    }

    setState(() => _isSending = true);
    final accepted = await widget.onSend(text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSending = false;
      if (accepted) {
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('home-ai-quick-record-bar'),
      height: 58,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('home-ai-image-button'),
            tooltip: '添加图片',
            onPressed: _isSending ? null : widget.onImagePressed,
            color: colorScheme.onSurfaceVariant,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey('home-ai-input'),
              controller: _controller,
              enabled: !_isSending,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: '记录此刻，AI 能力待接入…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          IconButton.filled(
            key: const ValueKey('home-ai-send-button'),
            tooltip: '发送',
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
