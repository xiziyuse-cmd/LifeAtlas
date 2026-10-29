import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/skincare_repository.dart';
import '../data/skincare_ai_service.dart';
import '../domain/skincare_models.dart';

class SkinProductPage extends StatefulWidget {
  const SkinProductPage({
    super.key,
    required this.repository,
    required this.ai,
    this.product,
  });
  final SkincareRepository repository;
  final SkincareAiService ai;
  final SkinProduct? product;
  @override
  State<SkinProductPage> createState() => _SkinProductPageState();
}

class _SkinProductPageState extends State<SkinProductPage> {
  final query = TextEditingController();
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late SkinProduct? selected = widget.product;
  List<SkinProduct> results = [];
  String? error;
  bool busy = false;
  int searchRevision = 0;
  @override
  void initState() {
    super.initState();
    if (selected == null) search('');
  }

  @override
  void dispose() {
    query.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> search(String q, {bool barcode = false}) async {
    final revision = ++searchRevision;
    try {
      final values = await widget.repository.search(q, barcode: barcode);
      if (mounted && revision == searchRevision) {
        setState(() {
          results = values;
          error = barcode && values.isEmpty ? '本地未收录此条码，可拍摄包装识别' : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '产品库读取失败，请返回重试');
    }
  }

  void choose(SkinProduct p) => setState(() {
    selected = p.copy({
      'id': widget.product?.id ?? skinId(),
      'versionConfirmed': false,
    });
    name.text = p.name;
  });
  Future<void> photo(ImageSource source) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('识别产品包装'),
        content: const Text(
          '所选图片会发送至已配置的 AI 服务。请拍摄清晰的品牌名称，或背面的成分和使用说明；结果确认后才保存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (consent != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final target = Directory('${directory.path}/lifeatlas/skincare');
      await target.create(recursive: true);
      final path = '${target.path}/${skinId()}.jpg';
      await picked.saveTo(path);
      final product = await widget.ai.identify(path);
      if (mounted) {
        choose(product);
        query.text = product.name;
        await search(product.name);
      }
    } catch (e) {
      if (mounted) setState(() => error = '识别失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodePage()),
    );
    if (barcode != null) {
      query.text = barcode;
      await search(barcode, barcode: true);
    }
  }

  Future<void> date(String field) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selected = selected!.copy({field: skinDate(picked)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = selected;
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? '添加护肤品' : '产品资料')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: query,
            onChanged: (q) => search(q),
            decoration: const InputDecoration(
              labelText: '搜索品牌、产品名称或别名',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => photo(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍照'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => photo(ImageSource.gallery),
                icon: const Icon(Icons.photo_outlined),
                label: const Text('相册'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫条码'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (p == null || query.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('产品库候选 · 请核对地区与包装'),
            for (final result in results)
              Card(
                child: ListTile(
                  title: Text(result.name),
                  subtitle: Text('${result.region} · ${result.category}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    choose(result);
                    query.clear();
                  },
                ),
              ),
            TextButton(
              onPressed: () {
                choose(SkinProduct(id: skinId(), name: query.text));
                query.clear();
              },
              child: const Text('未找到，先记录产品名称'),
            ),
          ],
          if (p != null) ...[
            const SizedBox(height: 20),
            Text('确认产品信息', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (p.image.isNotEmpty)
              SizedBox(
                height: 140,
                child: Image.file(
                  File(p.image),
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '产品名称'),
              onChanged: (v) => setState(
                () => selected = p.copy({
                  'name': v,
                  'versionConfirmed': v == p.name && p.versionConfirmed,
                  'evidence': v == p.name ? p.evidence : 'unknown',
                }),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: p.category,
              decoration: const InputDecoration(labelText: '分类'),
              items: skinCategories
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(
                () => selected = p.copy({
                  'category': v,
                  'evidence': v == p.category ? p.evidence : 'unknown',
                  'versionConfirmed': false,
                }),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${p.brand}\n地区：${p.region.isEmpty ? '待确认' : p.region}\n规格：${p.size.isEmpty ? '未知' : p.size}\n配方版本：${p.formula.isEmpty ? '待确认' : p.formula}',
            ),
            const Divider(height: 32),
            Text(
              '资料状态：${p.evidence == 'verified'
                  ? '官网资料已核实，个人包装待核对'
                  : p.evidence == 'ai'
                  ? 'AI 识别 · 待核实'
                  : '信息不足'}',
            ),
            SelectableText(
              '来源：${p.source.isEmpty ? '未提供' : p.source}\n核对日期：${p.verifiedAt.isEmpty ? '未知' : p.verifiedAt}',
            ),
            Text(
              '已知关键成分：${p.ingredients.isEmpty ? '未知' : p.ingredients.join('、')}\n浓度：${p.concentration ?? '未知'}\n宣称功效：${p.claims.isEmpty ? '未知' : p.claims.join('、')}\n使用说明：${p.instructions.isEmpty ? '待核实' : p.instructions}\n${p.cautions}',
            ),
            if (p.evidence == 'verified')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('已核对地区、产品版本和包装说明一致'),
                value: p.versionConfirmed,
                onChanged: (v) =>
                    setState(() => selected = p.copy({'versionConfirmed': v})),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: p.status,
              decoration: const InputDecoration(labelText: '使用状态'),
              items: [
                '使用中',
                '暂停使用',
                '已用完',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) =>
                  setState(() => selected = p.copy({'status': v})),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开封日期'),
              subtitle: Text(p.opened.isEmpty ? '未设置' : p.opened),
              onTap: () => date('opened'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('到期日期'),
              subtitle: Text(p.expires.isEmpty ? '未设置' : p.expires),
              onTap: () => date('expires'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (selected!.name.trim().isEmpty) {
                        setState(() => error = '请填写产品名称');
                        return;
                      }
                      if (p.opened.isNotEmpty &&
                          p.expires.isNotEmpty &&
                          p.opened.compareTo(p.expires) > 0) {
                        setState(() => error = '到期日期应晚于开封日期');
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await widget.repository.saveProduct(selected!);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            busy = false;
                            error = '保存失败，请重试';
                          });
                        }
                      }
                    },
              child: const Text('确认并保存到护肤柜'),
            ),
            if (widget.product != null)
              TextButton(
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('删除此产品？'),
                      content: const Text('历史护理记录保留，后续计划需要重新确认。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    try {
                      await widget.repository.deleteProduct(p.id);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (mounted) setState(() => error = '删除失败，请重试');
                    }
                  }
                },
                child: const Text('删除产品'),
              ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BarcodePage extends StatefulWidget {
  const _BarcodePage();
  @override
  State<_BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<_BarcodePage> {
  final controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool done = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('扫描产品条码')),
    body: MobileScanner(
      controller: controller,
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (!done && value != null) {
          done = true;
          Navigator.pop(context, value);
        }
      },
    ),
  );
}
