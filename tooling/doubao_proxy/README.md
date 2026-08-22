# LifeAtlas Doubao 图片识别代理

该代理用于把 Flutter 选择的衣服图片发送给火山方舟 `Doubao-Seed-2.1-pro`。供应商 API Key 只存在于代理进程环境变量中，不进入 App 或 Git。

## 开始前

如果 API Key 曾出现在截图、聊天、日志或提交记录中，先在火山方舟控制台删除该 Key，再创建新 Key。不要把真实值写入 `.env.example` 或任何受 Git 管理的文件。

需要 Node.js 18 或更高版本。代理没有第三方 npm 依赖。

## 本机启动（Windows PowerShell）

```powershell
Set-Location D:\Projects\LifeAtlas\lifeatlas\tooling\doubao_proxy
$env:ARK_API_KEY = Read-Host '输入新 ARK API Key'
$proxyToken = [guid]::NewGuid().ToString('N')
$env:LIFEATLAS_PROXY_TOKEN = $proxyToken
Write-Host "复制给 Flutter 的代理 Token：$proxyToken"
node server.mjs
```

默认只监听 `127.0.0.1:8787`。健康检查地址为：

```text
http://127.0.0.1:8787/health
```

## Android 模拟器启动 App

打开另一个 PowerShell 窗口，按提示粘贴代理窗口输出的开发期代理 Token：

```powershell
Set-Location D:\Projects\LifeAtlas\lifeatlas
$env:LIFEATLAS_PROXY_TOKEN = Read-Host '输入代理 Token'
flutter run --dart-define=LIFEATLAS_AI_PROXY_URL=http://10.0.2.2:8787/v1/wardrobe/analyze --dart-define=LIFEATLAS_AI_PROXY_TOKEN=$env:LIFEATLAS_PROXY_TOKEN
```

未传 `LIFEATLAS_AI_PROXY_URL` 时，App 保持“图片参数识别服务尚未配置”状态。

## 真机与生产环境

- Android 真机无法通过 `10.0.2.2` 访问电脑；本地调试可把代理 `HOST` 临时设置为 `0.0.0.0`，App 地址改为电脑局域网 IP。不要在不可信网络中这样运行。
- 生产环境必须将代理部署在 HTTPS 后，并使用正式用户登录鉴权、按用户限流、调用审计和预算上限。
- `LIFEATLAS_PROXY_TOKEN` 只是一层开发期共享校验，不能替代正式用户鉴权。
- 代理不会主动保存图片、API Key 或模型响应；运行平台仍需关闭含请求正文的访问日志。
- 可通过服务器环境变量 `ARK_MODEL` 覆盖默认的 `doubao-seed-2-1-pro-260628`。
