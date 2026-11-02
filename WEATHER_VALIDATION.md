# 天气调整交付记录（2.3.1+32）

## 基线与实现

从 GitHub `feature/skincare-v2` 的 `56fb90d` 建立 `feature/weather-hourly`；原本地分支保留。继续使用现有 MobileApi、和风后台代理、设置表与 timezone 库，没有新增数据库迁移。

- 首页保留地区、天气、今日区间、当前温度与可点击归因，隐藏获取时间与推荐文字。
- 天气卡片左下显示一次获取时间及来源官网，右下独立刷新；删除冗长说明。
- 卡片下方显示今明逐小时横向列表，按城市 IANA 时区分组，包含夏令时处理；不补造已过去或缺失的小时。
- 小时预报独立加载和报错；15分钟缓存按城市隔离；强制刷新同时绕过客户端、服务端缓存。失败仅回退同城仍覆盖有效时段的缓存，切城清除旧显示。首页不回退昨天的天气。

## 修改文件

Flutter：

- `lib/features/home/data/weather_service.dart`
- `lib/features/home/domain/hourly_weather.dart`
- `lib/features/home/presentation/home_page.dart`
- `lib/features/home/presentation/weather_detail_page.dart`
- `lib/features/home/presentation/widgets/home_weather_card.dart`
- `lib/features/home/presentation/widgets/weather_attribution.dart`
- `test/hourly_weather_test.dart`
- `test/weather_layout_test.dart`
- `pubspec.yaml`、`pubspec.lock`（官网链接引入 url_launcher；本机 Flutter SDK 同步其固定的传递依赖版本）
- `README.md`、`REQUIREMENTS.md`、`CHANGELOG.md`、本记录

配套后台位于相邻 `weather-admin-source`，提交 `bd0960a76d2f4d2f0a9ebcbd14b429b794db0961`：

- `lib/qweather.mjs`、`lib/hourly-weather.mjs`
- `app/api/mobile/route.ts`
- `test/hourly-weather.test.mjs`、`README.md`

## 验证

- Flutter 全量回归 144 项通过；天气专项覆盖跨日、夏令时重复小时、缓存有效期/损坏/切城/强刷、失败、360像素宽1.5倍字号、刷新按钮位置、页面销毁和首页时间隐藏。
- Flutter 静态分析通过。
- 最后首页失败状态修正后，静态分析与20项首页/天气相关复测通过。
- 后台 50 项测试与生产构建通过。Node 22.12 运行现有 SQLite 测试须加 `--experimental-sqlite`。
- 后台已通过 Sites 发布为版本24，保持原私有访问范围： https://lifeatlas-ai-console.xiziyuse.chatgpt.site 。
- 2026-11-02 13:48（北京时间）真实 App 网关验证：成都返回72小时，时区 `Asia/Shanghai`，首条当地14:00、多云、18.23℃。未把测试夹具当成真实接口验证。
- 和风官方接口说明：https://dev.qweather.com/docs/api/weather/weather-hourly-forecast/ 。归因说明：https://dev.qweather.com/docs/terms/attribution/ 。
- 本机未连接安卓设备，未进行真机/模拟器人工视觉检查；Windows 无法构建 iOS。正式签名更新包与微信发送不属于本次已验证交付。

## Android 验证包

- 最终构建时间：2026-11-02 13:53:45（北京时间），Release 构建成功。
- 实际包名 `com.example.lifeatlas`，版本 `2.3.1`，构建号 `32`，最低 Android API 24。
- 80,576,433 字节；SHA-256 `00C275DAC4F333B0B96483E477C095F20D0EB829FC0560C2E2D3A0D040346882`。
- APK v2签名验证通过，证书为 Android Debug；仅验证用途，不能当成固定正式签名的更新包。
- 文件：`build/app/outputs/flutter-apk/app-release.apk`；副本位于工作区 `release-files/LifeAtlas-2.3.1-validation.apk`。
