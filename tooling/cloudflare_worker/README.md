# LifeAtlas Cloudflare Worker

该 Worker 为正式 APK 提供 HTTPS Doubao 代理：

- `GET /health`
- `POST /v1/wardrobe/analyze`
- `POST /v1/wardrobe/preorder-analysis`

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
2. 用本目录的 `worker.js` 完整替换默认 Hello World。
3. 点击“部署”。
4. 访问 `https://<你的 Worker 域名>/health`，确认返回 `status: ok`。

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
