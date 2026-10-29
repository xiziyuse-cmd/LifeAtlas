# LifeAtlas 2.0.0 护肤模块交付记录

版本：2.0.0+27。开发基线：feature/kitchen 的 1.4.10。代码位于 feature/skincare-v2，通过 PR #4 审查；main 未合并。

## 使用流程

1. 我的 → 板块管理 → 开启护肤。
2. 建立皮肤档案，按部位选择问题，选择最多三个目标并调整顺序。
3. 搜索品牌/名称/别名，或拍摄/上传包装；扫码优先查本地，未匹配可主动查询 Open Beauty Facts。
4. 核对产品卡片的地区、规格、资料来源与包装。未知成分和浓度保持未知，不需要用户输入成分或功效。
5. AI 生成或选择基础规则方案。查看早晚步骤，调整护理日/顺序/用量/部位，确认启用新版本。
6. 开始早间或晚间护理，逐步完成/跳过。退出后可继续，结束后查看历史快照。
7. 在提醒设置中授权并设置早晚时间。

## 代码与数据

- `lib/features/skincare/domain`：档案、产品、计划、执行实体及保守规则。
- `lib/features/skincare/data`：SQLite 存取、独立目录导入、HTTPS AI 服务、公开条码查询。
- `lib/features/skincare/presentation`：首页、档案、智能录入、计划预览和执行页。
- `lib/features/skincare/application`：Android 本地非精确定时提醒。
- `assets/data/skincare_catalog.json`：带版本、来源和核对日期的精选目录。
- `lib/core/database/skincare_schema.dart`：v12 新表；旧表及已有数据不清理。
- `tooling/cloudflare_worker/skincare.js`：包装提取与结构化计划协议及校验；复用原登录鉴权。
- `todaySummary()`：为未来桌面组件提供今日计划和状态数据。

目录与个人护肤柜分开；目录更新不会覆盖个人产品。启用计划时保存产品资料快照，历史执行按日期+早晚唯一保存，产品删除、改名或新计划均不回写历史。

## 验证与构建

- 本地 Dart 全项目静态分析：通过，No issues found。
- `dart tooling/check_skincare_rules.dart`：18 项规则和社区条码解析检查通过。
- `node --test tooling/cloudflare_worker/*.test.mjs`：16 项通过。
- `test/skincare_test.dart`：新增目录版本隔离、字面量搜索、无效计划、执行幂等/快照、旧库无损迁移与设置测试。
- `test/skincare_widget_test.dart`：新增产品确认与计划预览→启用→执行流程测试。界面使用内存数据源，真实数据库由数据层测试验证。
- `.github/workflows/skincare-validation.yml`：完整 Flutter 测试、静态分析、Node 测试和 Android Release APK 构建与产物上传。
- 本地 Flutter 工具准备环境时请求云实例元数据，自动审批因凭据边界风险拦截；该请求已停止。本地未构建 APK、未向微信发送文件。完整 CI 与 APK 状态以 PR/Actions 最新结果为准。

## 当前边界与后续配置

- AI 新路由 `/v1/skincare/identify`、`/v1/skincare/plan` 的代码已加入 Worker，仍需部署到现有服务。沿用已有服务器加密变量和短期登录令牌，客户端不保存供应商密钥。接口未部署或失效时有明确提示和基础规则入口。
- 目录当前为 4 款美国官网资料，来源列在 JSON；不冒充覆盖全部常见品牌，也不将美国配方合并成中国或其他地区配方。目录可独立扩充/升级。
- 包装 AI 资料和 Open Beauty Facts 社区资料保持待核实，不自动升级成可靠配方资料；未知浓度始终留空。当前保守自动计划只使用资料版本已确认的产品；未收录产品可先保存到护肤柜。
- Open Beauty Facts 查询由用户主动触发，仅发送条码；资料保留 ODbL 来源标记，未批量导入自有目录，未下载其商品图片。
- Android 通知滚动安排未来 28 天，应用启动、恢复及数据变更后更新；系统省电设置可能延迟送达。关闭模块取消安排，已结束（含部分完成）护理不再提醒。超过 28 天不打开 App 时无后续新提醒。
- Android 需真机验证通知权限拒绝、系统重启、相机/扫码权限、长时间后台、省电限制和跨时区行为。系统回收图片选择进程后的恢复流程仍需补充验证。
- 当前 Android 工程的 Release 沿用既有 debug signing 配置；CI 生成的签名与原安装包是否相同尚未核验，不能声称已通过覆盖安装验收。
- iOS 仍可使用本地计划流程，通知未实现，未做 iOS 实机验证。桌面小组件只提供数据接口，未做原生 Widget。
- 手动用量和 AI 自然语言用量仍应遵循产品包装，规则层不具备每种产品精确剂量上限数据库。
