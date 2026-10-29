# 应用内更新

版本：2.1.1+29。保留护肤模块，不改变个人数据库。自动检查每次启动一次，失败不打断使用；手动入口为“我的 → 关于与更新”。

## 服务与管理

管理网站“版本发布”支持 APK 分片上传（8 MiB）、流式 SHA-256、草稿与发布分离、停止推送、构建号防回退。上传内容上限 160 MiB，数据保存在原有 R2 独立 updates/ 前缀。更新入口为 `https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest`。网关只允许读取已发布版本和该版本 APK，不开放网站其他资源，网站保持私有。

网站需要 UPDATE_SITE_AUTH（该 Site 的平台服务访问令牌）、UPDATE_INGRESS_KEY、UPDATE_SETUP_KEY 三个服务端密钥，更新网关使用管理员已保存的 Cloudflare 授权部署。后台“启用更新服务”按钮用于登录后的管理员；部署初始化入口只允许独立的 setup 密钥。

## 安装与签名

App 下载到私有缓存更新目录，拒绝跨域下载和重定向；校验长度和 SHA-256 后，Android PackageManager 再核对包名、实际版本、最低系统及当前签名。只对更新目录使用 FileProvider 临时读权限。签名不一致时不调用安装器，并保留现有数据。申请安装来源权限后用户返回页面再次点击安装。安装成功由系统处理，下次启动读取真实版本。此次不支持静默安装、强制升级、断点续传或签名轮换。

旧版手工签名配置（2.1.0；2.1.1 已改用自动托管）：
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


## 2.1.1 自动发布

用户只在 App 内检查、下载并确认安装。无需在管理网站上传 APK。流水线由指定仓库所有者的 push/手动运行触发，使用 GitHub OIDC 短期身份读取加密托管的固定签名，完成测试、构建和证书校验后自动创建 GitHub Release，再分片同步到更新服务、校验并启用活动版本。管理页手工上传仅作维护备用。

身份校验固定到仓库ID、所有者ID、分支、工作流文件及事件类型；拒绝 PR、Fork、其他工作流、过期/篡改令牌。签名在现有后台加密保存，初始化后禁止覆盖，不写入源码或安装包。临时 CI 私钥在任务结束清理。新增 `tooling/auto_release.py` 和 `tooling/test_auto_release.py`。

新固定正式证书 SHA-256：`5335ab3092b5a61d7f2dd1ac81efb36c6c6e4f02a7630dabff2db44f331685d2`。它是今后版本的固定签名，不匹配历史调试签名；旧应用仍需保留，不能假称保留数据直接覆盖。

自动发布同一版本不覆盖不同内容，更新服务拒绝同构建号冲突。App 包名仍为 `com.example.lifeatlas`，未更改数据库、未删除旧应用。

### 托管授权待确认

自动审批阻止向私有管理网站传输签名私钥、密码和服务访问凭据，要求明确授权具体资料及接收地址。固定签名已经生成并备份；托管初始化尚未确认成功。当前 `LIFEATLAS_AUTO_RELEASE=false`，CI 只构建验证包，不请求签名、不发布正式版本。

待授权目的地：用户所有且仅自己可见的 `https://lifeatlas-ai-console.xiziyuse.chatgpt.site`；用途为加密保存 LifeAtlas 固定签名，并仅向 `xiziyuse-cmd/LifeAtlas` 指定所有者、分支和工作流的短期 GitHub 身份提供签名配置。初始化和授权完成后启用自动发布，无需用户手动上传。
