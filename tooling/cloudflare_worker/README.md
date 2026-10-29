# LifeAtlas Cloudflare Worker

该 Worker 为正式 APK 提供 HTTPS Doubao 代理：

- `GET /health`
- `POST /v1/wardrobe/analyze`
- `POST /v1/wardrobe/preorder-analysis`
- `POST /v1/kitchen/recommend`：读取库存与口味要求，返回最多 5 道完整结构化菜谱。

## Cloudflare 加密变量

在 Worker 的“设置－变量和密钥”中添加以下“密钥”类型变量：

- `ARK_API_KEY`：重新创建且从未出现在截图、聊天或 Git 中的火山方舟 Key。
- `LIFEATLAS_LOGIN_USERNAME`：App 内登录使用的单账号用户名。
- `LIFEATLAS_LOGIN_PASSWORD`：至少 12 位、只用于本 App 的独立登录密码。
- `LIFEATLAS_AUTH_SIGNING_KEY`：至少 32 位的随机令牌签名密钥，可用两次 GUID 拼接生成。

可选普通运行时变量：

- `ARK_MODEL`，默认 `doubao-seed-2-1-pro-260628`。
- `ARK_TEXT_MODEL`，默认 `doubao-seed-2-1-turbo-260628`。
- `ARK_BASE_URL`，默认 `https://ark.cn-beijing.volces.com/api/v3`。

旧的 `LIFEATLAS_PROXY_TOKEN` 已不再使用，可以从 Cloudflare 删除。不要创建 `.env` 并提交真实值。Worker 不记录密码、令牌、请求正文、图片、模型正文或密钥。

## 通过 Cloudflare 网页部署

1. 打开独立 Worker `lifeatlas-ai-proxy` 的“编辑代码”。
2. 用本目录的 `worker.js` 替换入口，同时添加同目录模块 `kitchen.js`。入口保留 `import ... from './kitchen.js'`。
3. 点击“部署”。
4. 访问 `https://<你的 Worker 域名>/health`，确认返回 `status: ok`。

厨房推荐使用原有账号认证和 Turbo 模型，无需新增密钥。安装新版 APK 前应先部署这两个文件；旧 Worker 没有厨房路由时，客户端明确提示“厨房 AI 接口尚未部署”。本次本地自动化使用模拟模型响应验证代理契约，不代表已经部署或完成真实模型联调。

自定义厨房代理地址使用 `--dart-define=LIFEATLAS_KITCHEN_AI_PROXY_URL=https://<你的 Worker 域名>/v1/kitchen/recommend`。`npm test` 同时运行现有接口与厨房接口测试。

2026-09-08 部署记录：两个模块已部署到正式 `lifeatlas-ai-proxy`，活动版本 `df67f531`。正式健康检查返回 HTTP 200，厨房推荐未登录请求返回 HTTP 401。上述线上检查确认路由和认证配置生效，真实模型结果仍需 App 内登录后验收。

2026-09-09 部署记录：厨房库存请求增加 `remaining_days`，模型提示优先消耗临期食材并排除已过期食材；正式活动版本 `e7450766`。

## 正式 APK 构建

APK 只配置 Worker HTTPS 地址，不再包含固定代理口令、登录密码、签名密钥或供应商 Key。

```powershell
flutter build apk --release --dart-define=LIFEATLAS_AI_PROXY_URL=https://<你的 Worker 域名>/v1/wardrobe/analyze --dart-define=LIFEATLAS_TEXT_AI_PROXY_URL=https://<你的 Worker 域名>/v1/wardrobe/preorder-analysis --dart-define=LIFEATLAS_AI_AUTH_BASE_URL=https://<你的 Worker 域名>/v1/auth
```

## 安全边界

- APK 反编译无法获得 `ARK_API_KEY`，因为它只存在于 Cloudflare 加密变量中。
- APK 中只包含公开的 Worker URL；用户运行时登录后取得 15 分钟访问令牌和 30 天刷新令牌。
- 令牌保存在手机系统安全存储中；退出登录会清除本机令牌，轮换签名密钥会使全部现有令牌失效。
- 当前账号配置适合单用户自用；面向其他用户发布前仍需增加多用户数据库、单设备撤销、按用户限流、调用审计和预算告警。

## 护肤接口（2.0.0）

新增 POST `/v1/skincare/identify`（包装图片）及 `/v1/skincare/plan`（档案和产品列表）。复用既有短期令牌校验、服务端 ARK_API_KEY 与模型配置，不新增客户端密钥。需重新部署 Worker 后才可在线调用。客户端将未部署接口明确提示，并保留本地规则方案。照片识别仅提取可见信息，不能升级为已核实资料；客户端再次校验产品ID和护理规则。

### 护肤模型与独立开关（2026-10-29）

护肤包装识别和计划生成统一默认使用 `doubao-seed-2-1-turbo-260628`（Doubao-Seed-2.1-turbo）。可用 `ARK_SKINCARE_MODEL` 覆盖默认模型。
管理网站「功能与模型」新增「护肤识别与规划」开关；服务端读取 `LIFEATLAS_FEATURE_CONFIG.skincare` 的 `model` 与 `enabled`，关闭时两个接口均返回 `503 / FEATURE_DISABLED`，不会请求模型。旧三项配置升级时保留原配置，补充护肤默认值。
管理网站已提供代理自动备份及升级流程。使用旧线上代理时，在新版网站保存功能设置才会部署护肤接口及开关逻辑。App 无需因本次模型路由变更重新安装。
