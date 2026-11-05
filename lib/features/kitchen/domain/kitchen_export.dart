import 'kitchen_models.dart';
import 'shopping_list.dart';

class KitchenExport {
  KitchenExport({
    required this.title,
    required List<String> sections,
    this.image = '',
    this.label = 'LifeAtlas · 厨房',
    this.pageNote = '',
    this.pageTitle = '',
  }) : sections = List.unmodifiable(sections);
  final String title, image;
  final String label, pageNote, pageTitle;
  final List<String> sections;
  String get text => '$title\n\n${sections.join('\n\n')}';

  factory KitchenExport.recipe(Recipe recipe) {
    List<String> ingredients(List<RecipeMaterial> values) {
      final sorted = [...values]..sort((a, b) => a.sort.compareTo(b.sort));
      return sorted
          .map(
            (m) =>
                '${m.name}  ${m.quantity.isEmpty ? '用量待补' : m.quantity}'
                '${m.remark.isEmpty ? '' : '（${m.remark}）'}',
          )
          .toList();
    }

    return KitchenExport(
      title: recipe.name,
      image: recipe.image,
      sections: [
        '${recipe.categories.join(' · ')} · ${recipe.difficulty}\n预计制作 ${recipe.totalDuration} 分钟',
        '食材\n${recipe.materials.isEmpty ? '无' : ingredients(recipe.materials).join('\n')}',
        '调料\n${recipe.seasonings.isEmpty ? '无' : ingredients(recipe.seasonings).join('\n')}',
        '制作步骤',
        for (var i = 0; i < recipe.steps.length; i++)
          '${i + 1}. ${recipe.steps[i].name} · ${recipe.steps[i].duration}分钟'
              '${recipe.steps[i].parallelWithPrevious ? ' · 与上一步并行' : ''}\n'
              '${recipe.steps[i].content}'
              '${recipe.steps[i].materials.isEmpty ? '' : '\n食材：${recipe.steps[i].materials.join('、')}'}'
              '${recipe.steps[i].seasonings.isEmpty ? '' : '\n调料：${recipe.steps[i].seasonings.join('、')}'}',
      ],
    );
  }

  factory KitchenExport.shopping(
    Iterable<Recipe> recipes,
    ShoppingListState state,
  ) {
    final selected = recipes
        .where((r) => state.recipeIds.contains(r.id))
        .toList();
    final items = buildShoppingList(selected, servings: state.servings);
    String group(bool seasoning) => items
        .where((i) => i.seasoning == seasoning)
        .map(
          (i) =>
              '[${state.prepared.contains(i.key) ? '已准备' : '待准备'}] ${i.name}  ${i.quantity}',
        )
        .join('\n');
    return KitchenExport(
      title: '购物清单',
      sections: [
        '菜谱与份数\n${selected.map((r) => '${r.name} × ${state.portions(r.id!)}份').join('\n')}',
        '已准备 ${items.where((i) => state.prepared.contains(i.key)).length}/${items.length}',
        '食材\n${group(false).isEmpty ? '无' : group(false)}',
        '调料\n${group(true).isEmpty ? '无' : group(true)}',
      ],
    );
  }
}
