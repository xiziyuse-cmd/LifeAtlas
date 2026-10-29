import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/skincare_models.dart';
import '../data/skincare_repository.dart';

class SkinExecutionPage extends StatefulWidget {
  const SkinExecutionPage({
    super.key,
    required this.entry,
    required this.repository,
  });
  final SkinExecution entry;
  final SkincareRepository repository;
  @override
  State<SkinExecutionPage> createState() => _SkinExecutionPageState();
}

class _SkinExecutionPageState extends State<SkinExecutionPage> {
  late final states = [...widget.entry.states];
  late int index = !states.contains('pending') ? 0 : states.indexOf('pending');
  bool busy = false;
  String? error;
  Future<void> update(String value) async {
    setState(() {
      busy = true;
      error = null;
    });
    final next = [...states]..[index] = value;
    final entry = SkinExecution(
      date: widget.entry.date,
      period: widget.entry.period,
      planId: widget.entry.planId,
      steps: widget.entry.steps,
      states: next,
      updated: DateTime.now().toIso8601String(),
    );
    try {
      await widget.repository.progress(entry);
      if (!mounted) return;
      setState(() {
        states[index] = value;
        busy = false;
        if (index < states.length - 1) index++;
      });
      if (!states.contains('pending') && mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '保存进度失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.entry.steps[index];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.period == 'am' ? '早间护理' : '晚间护理'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${index + 1} / ${states.length} 步'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: states.where((s) => s != 'pending').length / states.length,
            ),
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((s.productSnapshot['image'] as String? ?? '')
                            .isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: Image.file(
                              File(s.productSnapshot['image'] as String),
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.spa_outlined, size: 48),
                            ),
                          )
                        else
                          const Icon(Icons.spa_outlined, size: 48),
                        const SizedBox(height: 24),
                        Text(
                          s.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        Text('用量\n${s.amount}'),
                        const SizedBox(height: 16),
                        Text('部位\n${s.area}'),
                        const SizedBox(height: 16),
                        Text(s.note),
                        const SizedBox(height: 16),
                        Text(
                          '状态：${{'pending': '待完成', 'done': '已完成', 'skipped': '已跳过'}[states[index]]}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (error != null) Text(error!),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: busy || index == 0
                      ? null
                      : () => setState(() => index--),
                  child: const Text('上一步'),
                ),
                TextButton(
                  onPressed: busy || index == states.length - 1
                      ? null
                      : () => setState(() => index++),
                  child: const Text('下一步'),
                ),
              ],
            ),
            FilledButton(
              onPressed: busy ? null : () => update('done'),
              child: const Text('完成这一步'),
            ),
            TextButton(
              onPressed: busy ? null : () => update('skipped'),
              child: const Text('跳过这一步'),
            ),
          ],
        ),
      ),
    );
  }
}
