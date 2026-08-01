import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder_card.dart';

class OutfitPage extends StatelessWidget {
  const OutfitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [
        FeaturePlaceholderCard(
          icon: Icons.checkroom_outlined,
          title: '我的衣柜',
          description: '衣服模型和数据库表结构已建立，衣柜业务将在后续阶段实现。',
          trailingLabel: '待实现',
        ),
        SizedBox(height: 12),
        FeaturePlaceholderCard(
          icon: Icons.style_outlined,
          title: '套装',
          description: '套装和衣服关联结构已预留，暂不提供新增和编辑。',
          trailingLabel: '待实现',
        ),
        SizedBox(height: 12),
        FeaturePlaceholderCard(
          icon: Icons.favorite_border,
          title: '预购衣服',
          description: '预购与 AI 分析不在本次基础框架范围内。',
          trailingLabel: '后续阶段',
        ),
      ],
    );
  }
}
