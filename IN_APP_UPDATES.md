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

## 已核验的历史签名

- GitHub v1.4.10：`0d34b5556500d8a2e1fa2f401bf594ca179f3833577d66a46ccb494652c0c775`
- 旧 CI v2.0.0：`531ea2c75b6794780786dcb769eb7d08bc3386e9f67d3dd33d30689b976c5955`

两者均为 Android Debug 证书。未找到原私钥保存记录。公钥证书不能用于还原私钥或重新签名。不要将旧2.0.0作为1.4.10的直接覆盖升级。

## 本次验证

- 源码验证提交：`9eb396871a588d57bae84ee73118329b76e55ae6`。
- Flutter静态分析无问题，126项Flutter测试与17项代理测试通过，Android Release验证构建成功。
- 工作流：<https://github.com/xiziyuse-cmd/LifeAtlas/actions/runs/40824453146>。
- 网站32项测试、TypeScript检查和构建通过；管理网站与独立更新网关均已发布。真实网关空版本响应200，其他路径404；护肤线上Turbo开关已启用。
- 本包是CI调试签名验证包，未发布为正式覆盖更新。当前环境不支持微信发送，未通过微信交付。
- 浏览器预览连接受限，网站视觉验收及Android真机安装授权/覆盖升级待完成。

## 修改文件

App：`lib/features/updates/app_update_service.dart`、`lib/features/updates/app_update_page.dart`、`lib/features/profile/presentation/profile_page.dart`、`lib/features/navigation/presentation/app_shell.dart`；Android：`MainActivity.kt`、`AndroidManifest.xml`、`res/xml/update_paths.xml`、`build.gradle.kts`；测试与发布：`test/app_update_test.dart`、`.github/workflows/skincare-validation.yml`、`pubspec.yaml`；文档：`README.md`、`REQUIREMENTS.md`、`CHANGELOG.md`、`IN_APP_UPDATES.md`、`UPDATE_RELEASE_NOTES.md`。

网站：`lib/app-updates.mjs`、`lib/update-gateway.mjs`、`lib/update-auth.ts`、`app/update-management.tsx`、`app/api/updates/`、`app/downloads/page.tsx`、`app/console.tsx`、`app/globals.css`、`cloudflare-env.d.ts`、`test/app-updates.test.mjs`。
