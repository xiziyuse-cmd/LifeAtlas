import 'package:flutter/material.dart';

/// A single full-width entry into global search.
class QuickRecordBar extends StatelessWidget {
  const QuickRecordBar({super.key, required this.onSearch});
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('home-ai-quick-record-bar'),
    children: [
      Expanded(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('home-global-search'),
            borderRadius: BorderRadius.circular(18),
            onTap: onSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '搜索全部内容，或问一个问题',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(onPressed: onSearch, child: const Text('搜索')),
    ],
  );
}
