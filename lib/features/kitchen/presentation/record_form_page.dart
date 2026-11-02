import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';

class RecordFormPage extends StatefulWidget {
  const RecordFormPage({
    super.key,
    required this.repository,
    required this.recipe,
  });
  final KitchenRepository repository;
  final Recipe recipe;
  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  DateTime _date = DateTime.now();
  int _score = 5;
  String _image = '';
  bool _busy = false;
  final _remark = TextEditingController();
  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('记录制作')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.recipe.name, style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          title: Text('制作日期：${kitchenDate(_date)}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null && mounted) setState(() => _date = date);
          },
        ),
        KitchenImage(_image),
        TextButton(
          onPressed: () async {
            try {
              final path = await pickKitchenMedia();
              if (path != null && mounted) setState(() => _image = path);
            } catch (e) {
              if (context.mounted) kitchenError(context, e);
            }
          },
          child: const Text('选择成品图片'),
        ),
        Wrap(
          children: [
            for (var s = 1; s <= 5; s++)
              IconButton(
                tooltip: '$s星',
                onPressed: () => setState(() => _score = s),
                icon: Icon(
                  s <= _score ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              ),
          ],
        ),
        TextField(
          controller: _remark,
          decoration: const InputDecoration(labelText: '备注'),
          maxLines: 4,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.repository.saveRecord(
                      CookingRecord(
                        recipeId: widget.recipe.id!,
                        recipeName: widget.recipe.name,
                        date: _date,
                        image: _image,
                        score: _score,
                        remark: _remark.text.trim(),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) kitchenError(context, e);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? '保存中…' : '保存制作记录'),
        ),
      ],
    ),
  );
}
