import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/outfit_set.dart';
import '../wardrobe_keys.dart';
import '../widgets/local_clothing_image.dart';

class OutfitSetFormPage extends StatefulWidget {
  const OutfitSetFormPage({
    super.key,
    required this.clothingItems,
    this.initialSet,
    this.now,
  });

  final List<ClothingItem> clothingItems;
  final OutfitSet? initialSet;
  final DateTime Function()? now;

  @override
  State<OutfitSetFormPage> createState() => _OutfitSetFormPageState();
}

class _OutfitSetFormPageState extends State<OutfitSetFormPage> {
  static const _seasons = ['春', '夏', '秋', '冬'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final Set<String> _selectedSeasons;
  late final Set<int> _selectedItemIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialSet?.name);
    _selectedSeasons = {...?widget.initialSet?.seasonTags};
    _selectedItemIds = {...?widget.initialSet?.clothingItemIds};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedSeasons.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个套装季节')));
      return;
    }
    if (_selectedItemIds.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('套装至少需要两件衣服')));
      return;
    }

    final initialSet = widget.initialSet;
    final now = (widget.now ?? DateTime.now)();
    Navigator.of(context).pop(
      OutfitSet(
        id: initialSet?.id,
        name: _nameController.text.trim(),
        seasonTags: [
          for (final season in _seasons)
            if (_selectedSeasons.contains(season)) season,
        ],
        clothingItemIds: [
          for (final item in widget.clothingItems)
            if (item.id case final id? when _selectedItemIds.contains(id)) id,
        ],
        createdAt: initialSet?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSet != null;
    return Scaffold(
      key: WardrobeKeys.outfitSetForm,
      appBar: AppBar(title: Text(isEditing ? '编辑套装' : '新增套装')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            TextFormField(
              key: WardrobeKeys.outfitSetNameField,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '套装名称 *',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入套装名称' : null,
            ),
            const SizedBox(height: 18),
            Text('所属季节', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final season in _seasons)
                  FilterChip(
                    key: WardrobeKeys.outfitSetSeason(season),
                    label: Text(season),
                    selected: _selectedSeasons.contains(season),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSeasons.add(season);
                        } else {
                          _selectedSeasons.remove(season);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择衣服',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('已选 ${_selectedItemIds.length} 件'),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.clothingItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('衣柜中还没有可加入套装的衣服'),
                ),
              )
            else
              for (final item in widget.clothingItems)
                if (item.id case final id?)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      key: WardrobeKeys.outfitSetSelection(id),
                      value: _selectedItemIds.contains(id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected ?? false) {
                            _selectedItemIds.add(id);
                          } else {
                            _selectedItemIds.remove(id);
                          }
                        });
                      },
                      secondary: LocalClothingImage(
                        imagePath: item.imagePath,
                        width: 52,
                        height: 52,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        [...item.seasonTags, ?item.category].join(' · '),
                      ),
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: WardrobeKeys.outfitSetSubmit,
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(isEditing ? '保存修改' : '保存套装'),
        ),
      ),
    );
  }
}
