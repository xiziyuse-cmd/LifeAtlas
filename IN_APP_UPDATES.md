# 应用内更新

版本：2.1.0+28。保留护肤模块，不改变个人数据库。自动检查每次启动一次，失败不打断使用；手动入口为“我的 → 关于与更新”。

## 服务与管理

管理网站“版本发布”支持 APK 分片上传（8 MiB）、流式 SHA-256、草稿与发布分离、停止推送、构建号防回退。上传内容上限 160 MiB，数据保存在原有 R2 独立 updates/ 前缀。更新入口为 `https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest`。网关只允许读取已发布版本和该版本 APK，不开放网站其他资源，网站保持私有。

网站需要 UPDATE_SITE_AUTH（该 Site 的平台服务访问令牌）、UPDATE_INGRESS_KEY、UPDATE_SETUP_KEY 三个服务端密钥，更新网关使用管理员已保存的 Cloudflare 授权部署。后台“启用更新服务”按钮用于登录后的管理员；部署初始化入口只允许独立的 setup 密钥。

## 安装与签名

App 下载到私有缓存更新目录，拒绝跨域下载和重定向；校验长度和 SHA-256 后，Android PackageManager 再核对包名、实际版本、最低系统及当前签名。只对更新目录使用 FileProvider 临时读权限。签名不一致时不调用安装器，并保留现有数据。申请安装来源权限后用户返回页面再次点击安装。安装成功由系统处理，下次启动读取真实版本。此次不支持静默安装、强制升级、断点续传或签名轮换。

正式构建必须使用固定签名。GitHub Actions Secrets：
- LIFEATLAS_RELEASE_KEYSTORE_BASE64
- LIFEATLAS_RELEASE_STORE_PASSWORD
- LIFEATLAS_RELEASE_KEY_ALIAS
- LIFEATLAS_RELEASE_KEY_PASSWORD

需要沿用已安装版本的原始私钥。历史 CI 临时调试签名的私钥无法从 APK 恢复；无法确认签名时不要卸载现有应用。未配置签名的 CI 只生成验证包，不上传正式 Release。正式签名配置完成后，push 会验证并发布 v2.1.0（已存在的版本不覆盖）。不得提交私钥或密码。

首次手动覆盖安装 2.1.0 后可应用内升级；1.4.x/2.0.0 没有这段功能，无法通过本次代码让已安装旧版本自行升级。Android 真机仍需验证安装来源授权、安装取消、覆盖安装和各厂商系统行为。
