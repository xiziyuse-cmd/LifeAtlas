import '../domain/kitchen_models.dart';

final presetRecipes = <Recipe>[
  Recipe(
    name: '西红柿炒鸡蛋',
    sourceType: 'preset',
    cookTime: 15,
    materials: const [
      RecipeMaterial(name: '鸡蛋', amount: 3, unit: '个', remark: '打散'),
      RecipeMaterial(name: '西红柿', amount: 2, unit: '个', remark: '切块'),
    ],
    seasonings: const [
      RecipeMaterial(name: '食用油', amount: 15, unit: 'ml', stage: '炒制阶段'),
      RecipeMaterial(name: '盐', amount: 2, unit: 'g', stage: '出锅前', sort: 2),
    ],
    steps: const [
      RecipeStep(
        name: '准备阶段',
        content: '西红柿洗净切块，鸡蛋打散。',
        duration: 5,
        materials: ['鸡蛋', '西红柿'],
      ),
      RecipeStep(
        name: '炒制阶段',
        content: '热锅加油，鸡蛋炒至凝固盛出。放入西红柿炒软，再放回鸡蛋翻炒。',
        duration: 8,
        materials: ['鸡蛋', '西红柿'],
        seasonings: ['食用油'],
      ),
      RecipeStep(
        name: '出锅前',
        content: '加入盐翻炒均匀，装盘。',
        duration: 2,
        seasonings: ['盐'],
      ),
    ],
  ),
  Recipe(
    name: '青椒土豆丝',
    sourceType: 'preset',
    cookTime: 20,
    materials: const [
      RecipeMaterial(name: '土豆', amount: 2, unit: '个', remark: '切丝后冲洗'),
      RecipeMaterial(name: '青椒', amount: 1, unit: '个', remark: '切丝'),
    ],
    seasonings: const [
      RecipeMaterial(name: '食用油', amount: 15, unit: 'ml', stage: '炒制阶段'),
      RecipeMaterial(name: '盐', amount: 2, unit: 'g', stage: '出锅前', sort: 2),
    ],
    steps: const [
      RecipeStep(
        name: '准备阶段',
        content: '土豆去皮切丝并冲洗，青椒去籽切丝。',
        duration: 10,
        materials: ['土豆', '青椒'],
      ),
      RecipeStep(
        name: '炒制阶段',
        content: '热锅加油，下土豆丝炒熟，再下青椒丝继续翻炒。',
        duration: 8,
        materials: ['土豆', '青椒'],
        seasonings: ['食用油'],
      ),
      RecipeStep(
        name: '出锅前',
        content: '加盐调味，翻炒均匀后装盘。',
        duration: 2,
        seasonings: ['盐'],
      ),
    ],
  ),
  Recipe(
    name: '紫菜蛋花汤',
    sourceType: 'preset',
    cookTime: 10,
    categories: const ['家常菜', '汤类'],
    materials: const [
      RecipeMaterial(name: '紫菜', amount: 5, unit: 'g'),
      RecipeMaterial(name: '鸡蛋', amount: 1, unit: '个'),
      RecipeMaterial(name: '水', amount: 500, unit: 'ml'),
    ],
    seasonings: const [
      RecipeMaterial(name: '盐', amount: 2, unit: 'g', stage: '出锅前'),
    ],
    steps: const [
      RecipeStep(
        name: '准备阶段',
        content: '鸡蛋打散，紫菜按包装说明清理。',
        duration: 3,
        materials: ['鸡蛋', '紫菜'],
      ),
      RecipeStep(
        name: '炖煮阶段',
        content: '水烧开后放入紫菜，缓缓倒入蛋液，煮至蛋液凝固。',
        duration: 6,
        materials: ['水', '紫菜', '鸡蛋'],
      ),
      RecipeStep(
        name: '出锅前',
        content: '加入盐搅匀后盛出。',
        duration: 1,
        seasonings: ['盐'],
      ),
    ],
  ),
];
