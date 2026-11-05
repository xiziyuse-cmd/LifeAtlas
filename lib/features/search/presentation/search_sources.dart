import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../home/presentation/weather_detail_page.dart';
import '../../kitchen/presentation/recipe_detail_page.dart';
import '../../kitchen/presentation/shopping_list_page.dart';
import '../../modules/presentation/modules_page.dart';
import '../../profile/presentation/body_profile_page.dart';
import '../../profile/presentation/theme_settings_page.dart';
import '../../updates/app_update_page.dart';
import '../../skincare/data/skincare_ai_service.dart';
import '../../skincare/presentation/skin_product_page.dart';
import '../../skincare/presentation/skin_plan_page.dart';
import '../../skincare/presentation/skin_execution_page.dart';
import '../../wardrobe/presentation/pages/clothing_detail_page.dart';
import '../../wardrobe/presentation/pages/outfit_sets_page.dart';
import '../../wardrobe/presentation/preorder_detail_page.dart';
import '../../wardrobe/data/preorder_analysis_service.dart';
import '../../wardrobe/data/wardrobe_image_service.dart';
import '../data/search_repository.dart';
import '../domain/search_document.dart';

class SearchSources {
  SearchSources({
    required this.controller,
    required this.repository,
    required this.kitchenPage,
    required this.wardrobePage,
    required this.skinPage,
    required this.skinAi,
    required this.imageService,
    required this.preorderAnalysis,
  });
  final AppController controller;
  final SearchRepository repository;
  final Widget Function(bool inventory) kitchenPage;
  final Widget Function() wardrobePage, skinPage;
  final SkincareAiService skinAi;
  final WardrobeImageService imageService;
  final PreorderAnalysisService preorderAnalysis;
  bool enabled(SearchCategory c) => switch (c) {
    SearchCategory.kitchen => controller.kitchenModuleEnabled,
    SearchCategory.wardrobe => controller.outfitModuleEnabled,
    SearchCategory.skincare => controller.skincareModuleEnabled,
    _ => true,
  };

  Future<void> open(BuildContext context, SearchDocument document) async {
    if (!enabled(document.category)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${document.category.label}板块已关闭'),
          content: const Text('已有数据仍然保留。是否重新启用后查看原内容？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('启用并查看'),
            ),
          ],
        ),
      );
      if (yes != true || !context.mounted) return;
      switch (document.category) {
        case SearchCategory.kitchen:
          await controller.setKitchenModuleEnabled(true);
        case SearchCategory.wardrobe:
          await controller.setOutfitModuleEnabled(true);
        case SearchCategory.skincare:
          await controller.setSkincareModuleEnabled(true);
        default:
          break;
      }
    }
    if (!context.mounted) return;
    final d = await repository.resolve(document);
    if (!context.mounted) return;
    final id = int.tryParse(d.entityId);
    Widget page;
    switch (d.target) {
      case 'recipe':
        final recipes = await repository.kitchen.listRecipes();
        page = RecipeDetailPage(
          recipe: recipes.firstWhere((r) => r.id == id),
          repository: repository.kitchen,
        );
      case 'clothing':
        final item = await repository.wardrobe.getClothing(id!);
        if (item == null) throw StateError('deleted');
        page = ClothingDetailPage(item: item);
      case 'preorder':
        final item = await repository.wardrobe.getPreorder(id!);
        if (item == null) throw StateError('deleted');
        page = PreorderDetailPage(
          repository: repository.wardrobe,
          item: item,
          imageService: imageService,
          analysisService: preorderAnalysis,
        );
      case 'set':
        page = OutfitSetsPage(
          repository: repository.wardrobe,
          clothingItems: await repository.wardrobe.listClothing(),
        );
      case 'product':
        final products = await repository.skincare.products();
        page = SkinProductPage(
          repository: repository.skincare,
          ai: skinAi,
          product: products.firstWhere((p) => p.id == d.entityId),
        );
      case 'plan':
        final plan = await repository.skincare.activePlan();
        if (plan == null || plan.id != d.entityId) throw StateError('changed');
        page = SkinPlanPage(plan: plan, repository: repository.skincare);
      case 'execution':
        final parts = d.entityId.split('|');
        final entry = await repository.skincare.execution(parts[0], parts[1]);
        if (entry == null) throw StateError('deleted');
        page = SkinExecutionPage(entry: entry, repository: repository.skincare);
      case 'shopping':
        page = ShoppingListPage(repository: repository.kitchen);
      case 'inventory':
      case 'kitchen':
        page = Scaffold(
          appBar: AppBar(title: const Text('厨房')),
          body: kitchenPage(d.target == 'inventory'),
        );
      case 'wardrobe':
        page = wardrobePage();
      case 'skincare':
        page = Scaffold(
          appBar: AppBar(title: const Text('护肤')),
          body: skinPage(),
        );
      case 'weather':
        page = WeatherDetailPage(service: repository.weather);
      case 'body':
        page = BodyProfilePage(controller: controller);
      case 'theme':
        page = ThemeSettingsPage(controller: controller);
      case 'updates':
        page = const AppUpdatePage();
      case 'modules':
        page = Scaffold(
          appBar: AppBar(title: const Text('板块管理')),
          body: ModulesPage(controller: controller),
        );
      case 'day':
        final date = DateTime.parse(d.entityId);
        final days = await repository.home.loadMonth(
          DateTime(date.year, date.month),
        );
        final day = days[date];
        page = Scaffold(
          appBar: AppBar(title: Text('${d.entityId} 生活记录')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (day == null || !day.hasAnyRecord) const Text('没有保存当天的记录'),
              for (final text in day?.textEntries ?? <String>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SelectableText(text),
                ),
              if (day?.hasOutfitRecord == true) const Text('当日穿搭'),
              for (final item in day?.outfitItems ?? [])
                ListTile(
                  title: Text(item.name),
                  onTap: () async {
                    try {
                      await open(
                        context,
                        SearchDocument(
                          id: 'clothing:${item.id}',
                          title: item.name,
                          category: SearchCategory.wardrobe,
                          kind: SearchKind.record,
                          target: 'clothing',
                          entityId: '${item.id}',
                        ),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('衣服已删除或暂时无法打开')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        );
      default:
        throw StateError('unknown source');
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}
