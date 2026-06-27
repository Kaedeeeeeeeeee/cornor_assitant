# Peek 上线准备计划

最后更新：2026-06-28 JST

这个文档是 Peek 从当前本地项目走到公开 landing page 和 Mac App Store 首发的工作台。后续执行、验收、补漏都以这里为准；如果产品、定价、域名、隐私口径或 App Store 配置发生变化，先更新本文件，再改代码或页面。

## 0. 已确认决策

| 项目 | 决策 |
| --- | --- |
| App 名称 | Peek |
| 发布者/版权名 | Zhang Shifeng |
| Bundle ID | `com.shifeng.peek` |
| 首发系统要求 | macOS 15.0 或更高版本 |
| 销售模式 | Mac App Store 一次买断 |
| 首发价格 | US$5.99 |
| 首发语言 | 简体中文、英语、日语 |
| Landing hosting | GitHub Pages 默认域名 |
| 计划网站 URL | `https://kaedeeeeeeeeee.github.io/cornor_assitant/` |
| Support email | `f.shera.09@gmail.com` |
| Landing analytics | 可以加，仅限官网，不嵌入 App |
| App analytics | 首发不加 App 内分析埋点 |
| 选中文字搜索 | 不是 v1 功能，不对外宣传 |
| 搜索引擎选择/Bing | 不是 v1 用户可见功能，不对外宣传 |

## 1. 当前事实基线

- 当前项目是 macOS SwiftUI/AppKit/WebKit 应用，Xcode 工程位于 `CornerAssistantApp/CornerAssistantApp.xcodeproj`。
- 当前 app 产品名为 Peek，包名工程仍保留 `CornerAssistantApp` 命名。
- `SlidePanelView.swift` 当前直接使用 `GoogleSearchProvider()`；`BingSearchProvider.swift` 存在，但不是用户可配置功能。
- 当前代码没有系统选中文字读取逻辑；不能在 landing 或 App Store 文案中宣传 selected text search。
- Landing 源设计来自 `/Users/user/Downloads/项目 Landing Page 设计.zip`，其中 `.dc.html` 是设计稿，不是生产站点。
- Landing 生产目录为 `CornerAssistantApp/landing-page`。
- App icon 已核对：`CornerAssistantApp/landing-page/assets/icon.png` 与 Xcode AppIcon 512@2x 像素一致，SHA-256 为 `1fdd1e4c18c4ce6bb80d1264807c8034c0af28a83aa9471a98a3d25a6ec436b0`，无需替换。
- `CornerAssistantApp/build/` 和历史 `.xcarchive` 里的导出产物视为陈旧产物，不能直接提交 App Store Connect。

## 1.1 本次本地验证记录

2026-06-27 已完成：

- Landing 本地服务：`http://127.0.0.1:4173/`。
- Playwright 验证通过：
  - 首页 1440px desktop、1024px tablet、390px mobile。
  - Privacy page desktop。
  - Support page desktop。
  - 页面返回 200，无控制台错误，无横向溢出，图片加载正常，三语切换正常。
- 静态资源验证通过：
  - `site.webmanifest` JSON 可解析。
  - `sitemap.xml` XML 可解析。
  - `assets/social-preview.png` 为 1200x630。
- Xcode Release build 通过：
  - `xcodebuild -project CornerAssistantApp.xcodeproj -scheme CornerAssistantApp -configuration Release -destination 'platform=macOS' build`
- Build 产物确认：
  - `CFBundleDisplayName = Peek`
  - `CFBundleIdentifier = com.shifeng.peek`
  - `CFBundleShortVersionString = 1.0`
  - `CFBundleVersion = 1`
  - `LSMinimumSystemVersion = 15.0`
  - `PrivacyInfo.xcprivacy` 已打包到 `Contents/Resources/PrivacyInfo.xcprivacy`

2026-06-27 进一步处理：

- Xcode Release build 仍通过。
- entitlement 已清理：
  - 移除 incoming network/server entitlement。
  - 移除 user-selected file read-only entitlement。
  - 移除 JIT runtime exception。
  - 保留 App Sandbox、network client、audio input。
- Info.plist 已更新：
  - `NSHumanReadableCopyright = Copyright 2026 Zhang Shifeng`
  - `NSMicrophoneUsageDescription = Websites opened in Peek may request microphone access for features such as calls or voice input.`
- App Store 上架材料已重写：`CornerAssistantApp/docs/AppStore-Materials.md`。
- App Category 已设置为 `public.app-category.productivity`，避免 Xcode archive validation warning。
- 已新增 App Store export 配置：`CornerAssistantApp/export_options_app_store.plist`。
- App Store archive 已生成到 `/tmp/peek-appstore/Peek.xcarchive`。
- Archive 产物确认：
  - universal: `x86_64` + `arm64`
  - bundle id: `com.shifeng.peek`
  - version: `1.0 (1)`
  - minimum macOS: `15.0`
  - category: `public.app-category.productivity`
  - entitlements: App Sandbox、network client、audio input
  - archive app entitlements 未包含 `get-task-allow`

当前发现的发布门槛：

- 本地 Release build 仍使用 `Apple Development` 签名，entitlements 里有 `com.apple.security.get-task-allow = true`；这个产物不能直接提交 App Store Connect，必须用 App Store distribution archive/export 重新签名。
- `/tmp/peek-appstore/Peek.xcarchive` 里的 archive app 已确认不含 `get-task-allow`，但 archive metadata 仍显示自动签名使用 `Apple Development`；最终提交物仍必须通过 App Store export/Organizer 重新签为 distribution。
- 当前保留 `audio-input`，用于内置 WebKit 页面可能请求的网页通话或语音输入；隐私页和 Info.plist 已同步说明。
- App Store export 已尝试，但失败：
  - `error: exportArchive Unable to process request - PLA Update available`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
  - 需要登录 Apple Developer/App Store Connect 接受 Program License Agreement 更新，并创建/刷新 `com.shifeng.peek` 的 App Store provisioning profile。
- 2026-06-27 23:29 JST 再次执行 `xcodebuild -exportArchive`，失败原因仍为同一组 Apple 后台阻塞。
- 2026-06-28 00:13 JST 再次执行 `xcodebuild -exportArchive`，失败原因更新为：
  - `error: exportArchive No Accounts`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
  - 当前机器 CLI/Xcode 没有可用于 App Store distribution export 的账号状态；仍需要登录 Xcode/Apple Developer 账号，并创建或刷新 `com.shifeng.peek` 的 App Store provisioning profile。

2026-06-27 源码发布风险收口：

- 已确认当前 5 个未提交源码文件均与上线准备相关：
  - `LaunchAtLoginManager.swift`: 从手写 LaunchAgent/`launchctl` 改为 `SMAppService.mainApp`。
  - `SlidePanelController.swift`: 移除私有 cursor selector，改用自定义公开 API cursor。
  - `WebViewStore.swift`: 移除 `drawsBackground` KVC，改用 `underPageBackgroundColor = .clear`。
  - `SlidePanelView.swift` / `SlidePanelViewModel.swift`: 增加固定站点和普通标签拖拽排序；固定站点排序通过现有 `PinnedSiteStore` 保存。
- 发布风险扫描已通过，源码中没有再命中：
  - `NSSelectorFromString`
  - `drawsBackground`
  - `setValue(`
  - `launchctl`
  - `LaunchAgents`
  - `ProgramArguments`
- 清理后再次验证：
  - Release build 成功。
  - Archive 成功生成到 `/tmp/peek-appstore/Peek.xcarchive`。
  - Archive Info.plist、entitlements、`PrivacyInfo.xcprivacy` 均已从归档产物中复核。

2026-06-27 自动化测试收口：

- 已新增 shared Xcode scheme：`CornerAssistantApp.xcodeproj/xcshareddata/xcschemes/CornerAssistantApp.xcscheme`。
- 已修复 `CornerAssistantAppTests` 的 `TEST_HOST`，从旧的 `CornerAssistantApp.app/CornerAssistantApp` 改为实际产物 `Peek.app/Peek`。
- 已新增 unit tests：
  - `CornerAssistantAppTests/SearchProviderTests.swift`
  - `CornerAssistantAppTests/PinnedSiteTests.swift`
- 已验证通过：
  - `xcodebuild -project CornerAssistantApp.xcodeproj -scheme CornerAssistantApp -destination 'platform=macOS' -only-testing:CornerAssistantAppTests test`
  - `xcodebuild -project CornerAssistantApp.xcodeproj -scheme CornerAssistantApp -destination 'platform=macOS' -skip-testing:CornerAssistantAppUITests test`
  - 10 tests passed, 0 failures。
- 已验证 Release build 和 archive 在新增测试/scheme 后仍通过。
- 完整 UI test 当前无法作为自动 gate：
  - `xcodebuild test` 的 UI runner 初始化失败：`System authentication is running` / `Authentication canceled`。
  - 这属于当前 macOS 用户会话/系统认证状态阻塞；不作为代码失败处理。

2026-06-27 本地运行和 smoke QA 收口：

- 已新增项目本地运行入口：
  - `script/build_and_run.sh`
  - `.codex/environments/environment.toml`
- `script/build_and_run.sh --verify` 已验证通过：
  - 构建 `CornerAssistantApp.xcodeproj`。
  - 启动 `DerivedData/PeekRun/Build/Products/Debug/Peek.app`。
  - 确认 `Peek` 进程存在。
- 已新增 Debug-only 面板控制通知：
  - `com.shifeng.peek.debug.panelCommand`
  - 支持 `expand`、`collapse`、`toggle`。
  - 仅在 `#if DEBUG` 编译，不进入 Release/App Store 构建。
- 已新增 `script/qa_smoke.sh` 并验证通过：
  - 启动 Debug app。
  - 发送 debug `expand` 命令。
  - 从 Window Server 确认真实 Peek 面板窗口可见。
  - 最近一次输出：`window id=8359 layer=3 bounds=["Y": 281, "Height": 750, "Width": 528, "X": 0]`。
- 自动截图尝试结果：
  - `screencapture` 产物为全黑图。
  - `screencapture -l` 对可见窗口返回 `could not create image from window`。
  - 当前 Codex/shell 会话不能作为 App Store 截图来源；需要在授予 Screen Recording 权限、可见桌面和干净测试环境中采集真实截图。
- Debug-only 面板命令加入后已重新验证：
  - Release build 成功。
  - `xcodebuild ... -skip-testing:CornerAssistantAppUITests test` 成功。
  - Release archive 成功生成到 `/tmp/peek-appstore/Peek.xcarchive`。
  - Archive Info.plist、entitlements、`PrivacyInfo.xcprivacy` 均通过复核。
  - Release archive 可执行文件中未包含 `com.shifeng.peek.debug.panelCommand`。

2026-06-28 发布验证脚本收口：

- 已新增 `script/launch_verify.sh`，作为发布前一键 gate。
- `script/launch_verify.sh` 已验证通过，覆盖：
  - App Store metadata 长度和禁用词校验。
  - Release build。
  - 跳过 UI runner 的 XCTest。
  - Release archive。
  - Archive Info.plist 关键字段。
  - Archive entitlements。
  - Archive `PrivacyInfo.xcprivacy`。
  - Debug-only 面板命令没有进入 Release archive。
  - 公网 landing 关键 URL 均可达。

2026-06-28 截图采集脚本收口：

- 已新增 `script/capture_app_store_screenshot.sh`。
- 脚本默认输出到 `/tmp/peek-app-store-screenshots`，避免未审校截图直接进入仓库；需要保存到项目内时可设置 `OUT_DIR=CornerAssistantApp/docs/app-store-screenshots`。
- 脚本会：
  - 启动 Debug app。
  - 通过 Debug-only 通知展开真实 Peek 面板。
  - 从 Window Server 定位 Peek 面板窗口。
  - 用 `screencapture -l` 按窗口 ID 捕获。
  - 自动拒绝黑图/空图。
  - 生成 2880x1800 的 16:10 App Store 候选图。
- 2026-06-28 在当前 Codex/shell 会话运行结果：
  - 成功定位 Peek 面板窗口：`window id=8433 bounds=0,281 528x750`。
  - 截图阶段失败：`could not create image from window`。
  - 结论：脚本可复跑，但当前会话仍缺少可用 Screen Recording/可见桌面截图能力；需要在已授权的可见桌面会话中重跑。

2026-06-28 App Store metadata 校验收口：

- 已新增 `script/validate_app_store_materials.py`。
- 已修正三语言关键词，确保 App Store Connect keywords 字段不超过 100 bytes：
  - 中文关键词：98 bytes。
  - English keywords: 93 bytes。
  - 日本語キーワード：90 bytes。
- 当前 metadata 校验通过：
  - App name <= 30 chars。
  - Subtitle <= 30 chars。
  - Description <= 4000 chars。
  - Keywords <= 100 bytes。
  - What's New <= 4000 chars。
  - 未命中 `Bing`、`macOS 14`、`Sonoma`、selected text / 选中文字等禁用宣传词。
- `script/launch_verify.sh` 已纳入该校验。

2026-06-27 Export Compliance 收口：

- 已确认源码没有自研加密、CryptoKit、CommonCrypto、Security/SecKey/SecItem、OpenSSL/libsodium 等加密实现；网络访问来自 `URLSession`、WebKit 和系统框架。
- 已在主 app Debug/Release build settings 添加：
  - `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
- 已验证 Release build 成功。
- 已验证 unit tests 成功：
  - `xcodebuild -project CornerAssistantApp.xcodeproj -scheme CornerAssistantApp -destination 'platform=macOS' -skip-testing:CornerAssistantAppUITests test`
- 已重新生成 `/tmp/peek-appstore/Peek.xcarchive`。
- Archive Info.plist 已确认：
  - `ITSAppUsesNonExemptEncryption = false`
- App Store Connect Export Compliance 建议按“不使用非豁免加密”填写；如果后续加入自研加密、VPN、端到端加密、密码管理、加密消息、加密文件存储或第三方加密库，必须重新评估。

## 1.2 本次部署记录

2026-06-27 已完成：

- GitHub Pages 已通过 GitHub REST API 启用为 workflow 模式。
- Pages HTTPS enforced。
- 已提交并推送 commit：`fff1270 launch: prepare Peek landing and App Store release`。
- GitHub Actions workflow `Deploy Peek landing page` 成功：
  - Run ID: `28291446993`
- 公网 URL 已验证：
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/` -> 200
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html` -> 200
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html` -> 200
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/robots.txt` -> 200
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml` -> 200
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/assets/social-preview.png` -> 200
- 线上 Playwright 验证通过：
  - 首页、隐私页、支持页 mobile 390px 均返回 200。
  - 无控制台错误。
  - 无横向溢出。
  - 图片加载正常。
  - Privacy page 英文/日文切换正常。
  - 未发现 `Bing`、`macOS 14`、`Sonoma`、selected-text/选中文字等禁用公开宣传。

2026-06-27 对比度修复后重新部署：

- 已提交并推送 commit：`d19795d fix: improve landing page contrast`。
- GitHub Actions workflow `Deploy Peek landing page` 成功：
  - Run ID: `28291958776`
- 公网 CSS 已确认更新：
  - `--accent: #0064d2`
- 公网 URL 再次验证：
  - 首页、隐私页、支持页、`robots.txt`、`sitemap.xml` 均返回 200。
- 公网 Lighthouse 已执行：
  - Performance: 98
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100
  - `color-contrast` 已通过。

2026-06-27 Landing analytics 配置收口：

- 已提交并推送 commit：`f8f6643 build: allow pages analytics configuration`。
- GitHub Actions workflow `Deploy Peek landing page` 成功：
  - Run ID: `28292355748`
- 已新增 `CornerAssistantApp/landing-page/analytics-config.js`，默认不启用 analytics。
- 已更新 GitHub Pages workflow：部署时会读取 GitHub repository variable `PEEK_GA_MEASUREMENT_ID`。
- 如果 `PEEK_GA_MEASUREMENT_ID` 符合 `G-...` 格式，workflow 会写入 `analytics-config.js` 并启用官网 GA4；如果为空或格式不匹配，官网不会加载 Google Analytics。
- 公网已验证：
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/analytics-config.js` -> 200
  - 当前内容为 `window.PEEK_GA_MEASUREMENT_ID = "";`，即当前公网默认不加载 GA。
  - 首页 JSON-LD `applicationCategory = Productivity`。
- 本地 Lighthouse 验证通过：
  - Performance: 100
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100
- 公网 Lighthouse 验证通过：
  - Performance: 98
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100
- 首页 JSON-LD `applicationCategory` 已从 `UtilitiesApplication` 调整为 `Productivity`，与 App Store 分类保持一致。

## 2. 首发完成定义

首发上线不是只把页面放出去，也不是只上传一个 build。完成定义如下：

- Landing page、Privacy Policy、Support page 都可通过 HTTPS 公网访问。
- Landing 页面视觉接近已接受设计，三语切换正常，页面没有未实现功能宣传。
- SEO 基础文件齐全：canonical、meta description、Open Graph、Twitter Card、JSON-LD、`robots.txt`、`sitemap.xml`、favicon/social image。
- Landing analytics 已接入或明确等待 GA4 Measurement ID，不影响页面发布。
- App Store Connect 里 App 信息、价格、隐私、截图、支持链接、审核备注都与真实 App 一致。
- Release build 使用正确 bundle id、版本号、签名、sandbox entitlement 和 privacy manifest。
- Build 上传并通过 App Store Connect 处理后，提交给 App Review。
- 审核通过后，landing CTA 指向真实 Mac App Store URL。

## 3. 工作流总览

### Phase A: Landing Page 首发配置

状态：公网已部署；GA4 Measurement ID 和最终 App Store URL 待补。

- [x] 使用 GitHub Pages 默认域名作为首发域名。
- [x] 使用真实 App icon。
- [x] 将设计稿转成生产静态站点入口：`index.html`、`style.css`、`main.js`。
- [x] 页面文案改为真实 v1 功能：
  - 热角/屏幕边缘唤出。
  - 快捷搜索和 URL 打开。
  - WebKit 轻量浏览。
  - 多标签。
  - 固定常用网站。
  - 本地偏好保存。
- [x] 移除或避免宣传：
  - 选中文字搜索。
  - Bing 或搜索引擎可选。
  - macOS 14 兼容。
- [x] 支持简体中文、英语、日语三语切换。
- [x] 增加 Privacy Policy 页面。
- [x] 增加 Support 页面。
- [x] 增加 landing-only analytics loader。
- [ ] 配置真实 GA4 Measurement ID。
  - 当前 loader 已就绪，但默认不加载任何 analytics。
  - 拿到 ID 后在 GitHub repository variable 中设置 `PEEK_GA_MEASUREMENT_ID`，然后手动 rerun `Deploy Peek landing page` workflow 或推送 landing 变更。
- [x] 增加 GitHub Pages Actions workflow。
- [x] 在 GitHub 仓库中启用 GitHub Actions Pages 发布源。
- [x] 合并/推送后验证 Pages 公网 URL。
- [ ] App Store URL 出来后，把 CTA 从 “Coming soon” 改成真实链接。

### Phase B: SEO 基础

状态：本地基础和公网验证已完成；Lighthouse 已完成；Search Console/Webmaster Tools 待登录后台操作。

- [x] 设置 canonical host：`https://kaedeeeeeeeeee.github.io/cornor_assitant/`。
- [x] 首页、隐私页、支持页设置独立 title 和 meta description。
- [x] 增加 Open Graph 和 Twitter Card metadata。
- [x] 增加 `SoftwareApplication` JSON-LD。
  - `applicationCategory = Productivity`
- [x] 增加 `site.webmanifest`。
- [x] 增加 `robots.txt`。
- [x] 增加 `sitemap.xml`。
- [x] 生成 `assets/social-preview.png`。
- [x] 部署后检查：
  - 首页、隐私页、支持页返回 200。
  - `robots.txt` 返回 200。
  - `sitemap.xml` 返回 200。
  - 社交卡片图片返回 200。
  - canonical URL 和最终 Pages URL 一致。
  - 页面没有 `noindex`。
- [ ] 部署后提交：
  - Google Search Console。
  - Bing Webmaster Tools。
  - Sitemap URL。
  - 2026-06-28 检查结果：Search Console 已登录 `f.shera.09@gmail.com`，但该属性尚未验证；Bing Webmaster Tools 尚未登录。
- [x] 部署后跑 Lighthouse，记录性能和 SEO 分数。
- [ ] PageSpeed Insights 在线报告可后续补充，不阻塞首发。
  - 2026-06-28 通过 PageSpeed Insights API 请求移动端/桌面端报告时返回 HTTP 429 Too Many Requests；本项继续作为非阻塞补充项。

搜索引擎提交说明：

- `robots.txt` 已公开声明 sitemap：`https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml`。
- Google Search Console 和 Bing Webmaster Tools 需要登录对应账号后提交 sitemap；不要使用旧式匿名 sitemap ping 端点作为上线证据。
- 提交 sitemap 会改变站长工具账号状态，执行前需要确认使用哪个 Google/Microsoft 账号。
- Search Console 当前下一步是完成 `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 的所有权验证；GitHub Pages 可优先使用 HTML 文件或 HTML meta tag 验证方式。

首发关键词方向：

- Primary: `macOS menu bar browser`
- Supporting:
  - `Mac edge panel`
  - `macOS quick search`
  - `menu bar web browser`
  - `Mac pinned sites`
  - `Mac productivity utility`

中文和日文关键词可以后续根据搜索量再做内容扩展；首发先保证页面可信、可索引、可分享。

### Phase C: App Store Connect 准备

状态：待 App Store Connect 操作。

2026-06-27 App Store Connect 只读检查：

- 已尝试用应用内浏览器打开 `https://appstoreconnect.apple.com/agreements/`。
- 页面在加载阶段超时，未进入可读后台状态；没有提交任何表单，也没有接受协议。
- 当前 Apple 后台阻塞仍以 `xcodebuild -exportArchive` 的直接错误为准：PLA 更新待接受，且没有 `com.shifeng.peek` App Store provisioning profile。

2026-06-28 后台可达性复查：

- App Store Connect agreements：
  - 浏览器可到达 `https://appstoreconnect.apple.com/login?targetUrl=/agreements/`。
  - 当前没有已登录 App Store Connect 会话，无法进入 Agreements, Tax, and Banking；没有提交任何表单。
- Google Search Console：
  - 当前浏览器已登录 `f.shera.09@gmail.com`。
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 属性未验证，页面提示“このプロパティへのアクセス権がありません”。
  - 点击“所有権を証明”在当前浏览器自动化会话中超时，未进入验证方式页，也没有提交验证。
- Bing Webmaster Tools：
  - 当前停留在公开介绍页 `https://www.bing.com/webmasters/about`。
  - 没有已登录 Microsoft Webmaster Tools 会话；未提交站点。

2026-06-27 App Store Connect 表单材料补齐：

- `CornerAssistantApp/docs/AppStore-Materials.md` 已补充可照填字段：
  - App record。
  - Pricing and Availability。
  - Age Rating 问卷建议。
  - Content Rights / Third-Party Content。
  - App Review Information。
  - EU DSA / Trader Status 准备项。
- 年龄分级关键口径：
  - Peek 是 browser-like WebKit app，用户可以输入 URL、搜索或打开固定网站。
  - `Unrestricted Web Access` 必须按真实能力填写 `Yes`。
  - App 本身不内置暴力、色情、赌博、医疗、UGC、广告或原生聊天内容。
  - 最终年龄分级由 App Store Connect 根据问卷自动计算；不要在公开文案里承诺更低年龄分级。
- 内容权利关键口径：
  - Peek 不打包、镜像、缓存或再分发第三方内容。
  - 第三方网页只在用户主动输入 URL、搜索、点击结果或打开固定网站时访问。
  - App 自带素材、icon、landing 文案和截图应确保归开发者所有或已授权。

- [ ] Apple Developer Program 账号可用。
- [ ] Paid Apps Agreement 已签署。
- [ ] Apple Developer Program License Agreement 更新已接受。
- [ ] 税务和银行信息已配置，否则 US$5.99 付费销售无法上线。
- [ ] 创建 macOS App 记录：
  - Name: Peek
  - Bundle ID: `com.shifeng.peek`
  - SKU: 建议 `peek-macos-001`
  - Primary language: English (U.S.)。
- [ ] 设置价格和销售区域：
  - Price: US$5.99 对应 Apple 价格层级。
  - Availability: 首发区域需确认；默认建议全球可售，除非合规原因需要排除。
- [ ] 填写 Marketing URL：
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/`
- [ ] 填写 Privacy Policy URL：
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html`
- [ ] 填写 Support URL：
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html`
- [ ] 填写 App Privacy：
  - App 不收集开发者服务器侧个人数据。
  - 本地偏好和固定站点保存在用户 Mac。
  - Web 和搜索请求发往对应第三方网站或默认搜索服务。
  - 官网 analytics 不等于 App 内数据收集，App Store App Privacy 只按 App 行为填写。
- [ ] 填写年龄分级：
  - App Store Connect 问卷建议已写入 `CornerAssistantApp/docs/AppStore-Materials.md`。
  - `Unrestricted Web Access = Yes`。
- [x] 填写出口合规/加密说明。
- [ ] 填写版权、内容权利和地区合规信息：
  - Copyright: `2026 Zhang Shifeng`。
  - Content Rights 建议说明已写入 `CornerAssistantApp/docs/AppStore-Materials.md`。
  - 如果首发包含 EU，需要完成 DSA trader status 声明。
- [x] 准备 App Review notes 草稿：
  - 如何唤出面板：移动鼠标到热角。
  - 如何测试搜索/URL。
  - 如何测试标签页。
  - 如何测试固定站点。
  - 不需要账号。
  - Support email。
- [ ] 在 App Store Connect 粘贴 App Review notes 并填写真实审核联系电话。

### Phase D: App Store 文案和素材

状态：首发文案已审校并更新。

- [x] 审校 `CornerAssistantApp/docs/AppStore-Materials.md`。
- [x] 保证中英日文案一致：
  - macOS 15.0+。
  - 不说选中文字搜索。
  - 不说搜索引擎可选。
  - 不说 App 内 analytics。
  - 不说云同步、账号、团队协作等未实现功能。
- [x] 设置 subtitle：
  - 中文：`屏幕边缘的快捷助手`
  - English: `Quick Access from Screen Edge`
  - 日本語：`画面端からクイックアクセス`
- [x] 准备关键词，控制在 App Store 限制内。
  - 2026-06-28 已用 `script/validate_app_store_materials.py` 验证三语言 keywords 均不超过 100 bytes。
- [x] 准备 What's New 1.0 文案。
- [ ] 准备 Mac App Store 截图。

建议首发截图组：

1. 热角唤出边缘面板。
2. 搜索/URL 输入。
3. 多标签浏览。
4. 固定常用网站侧栏。
5. 设置或菜单栏状态。

截图要求：

- 使用干净桌面和真实 app build。
- 不出现开发工具、测试数据、个人隐私信息。
- 不展示未实现功能。
- 尽量覆盖中文、英文或日文中的至少一种主语言；如果 App Store Connect 支持本地化截图，后续再补全三语。
- 当前机器已有 `/Applications/Peek.app` 运行；为避免干扰用户当前桌面，本次没有自动控制该实例采集截图。
- 当前自动化会话已能用 `script/qa_smoke.sh` 展开真实 Debug 面板，但 `screencapture` 在该会话下只能得到黑图，不能作为 App Store 截图素材。
- 已新增 `script/capture_app_store_screenshot.sh` 作为可复跑截图入口；当前会话运行到窗口定位后被 `screencapture` 权限/会话状态阻塞。
- 建议截图采集方式：
  - 在可见干净桌面中授予当前终端/Codex 宿主 Screen Recording 权限。
  - 先运行 `./script/capture_app_store_screenshot.sh` 采集 Debug 面板候选图；脚本会拒绝黑图并生成 2880x1800 PNG。
  - 如果需要严格使用 distribution build，再使用 `/tmp/peek-appstore/Peek.xcarchive/Products/Applications/Peek.app` 或最终 exported app 手动采集。
  - 在干净桌面/测试用户中打开 app。
  - 用菜单栏图标或热角展示面板。
  - 只截取 app 窗口或经过清理的完整桌面。
  - 采集完成后保存到 `CornerAssistantApp/docs/app-store-screenshots/` 或外部素材目录，再决定是否提交进仓库。
- Mac App Store 官方接受 16:10 截图：1280x800、1440x900、2560x1600、2880x1800；建议首发使用 2880x1800 或 2560x1600。

### Phase E: App Build Readiness

状态：本地 Release build 和 archive 已通过，权限已收窄；App Store distribution export 被 Xcode account/profile/Apple 后台阻塞。

- [x] 明确当前 dirty worktree 哪些是本次上线工作，哪些是用户已有改动。
- [x] 确认版本号：
  - `MARKETING_VERSION = 1.0`
  - `CURRENT_PROJECT_VERSION` 每次上传递增。
- [x] 确认 bundle metadata：
  - Bundle ID: `com.shifeng.peek`
  - Display name: `Peek`
  - Minimum macOS version: 15.0
  - Copyright: `© 2026 Zhang Shifeng`
  - `ITSAppUsesNonExemptEncryption = false`
- [x] 确认 App Sandbox entitlement。
- [x] 确认 WebKit 浏览需要的 network client entitlement。
- [x] 检查是否真的需要 audio input entitlement；保留给 WebKit 页面请求麦克风，Info.plist 和 privacy copy 已同步。
- [x] 确认 archive app entitlements 没有 `com.apple.security.get-task-allow`。
- [ ] 确认最终 App Store exported app 没有 `com.apple.security.get-task-allow`。
- [x] 确认 `PrivacyInfo.xcprivacy` 已加入 target 并打包进 app。
- [x] 确认 app icon 和 bundle icon 使用真实 Peek icon。
- [ ] 确认 menu bar icon 在真实运行环境中显示正常。
- [x] 设置 App category：
  - `public.app-category.productivity`
- [x] 运行 Release build：

```bash
xcodebuild \
  -project CornerAssistantApp/CornerAssistantApp.xcodeproj \
  -scheme CornerAssistantApp \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

- [x] 创建新的 archive，不复用历史 build：

```bash
xcodebuild archive \
  -project CornerAssistantApp/CornerAssistantApp.xcodeproj \
  -scheme CornerAssistantApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath /tmp/peek-appstore/Peek.xcarchive \
  -allowProvisioningUpdates
```

- [ ] 用 Xcode Organizer 或 `xcodebuild -exportArchive` 走 App Store distribution。
  - 已新增 `export_options_app_store.plist`。
  - 当前 export 被 Xcode account/profile 阻塞：`No Accounts`，且没有 `com.shifeng.peek` profile。
  - 登录账号后仍需确认 Apple Developer PLA 是否已接受。
- [x] 发布前一键验证脚本：

```bash
./script/launch_verify.sh
```

  - 2026-06-28 已通过。
- [ ] 上传 App Store Connect：
  - Xcode Organizer。
  - 或 Transporter。
  - 或 `xcrun altool`/`notarytool` 相关流程按 Apple 当前推荐工具确认。

注意：

- Mac App Store 提交重点是 App Store 签名和 App Store Connect 上传；独立分发才强依赖 notarization。不要把普通本地 debug 和分发签名问题混在一起判断。
- 历史 `CornerAssistantApp/build/` 和 `.xcarchive` 只作为参考，不能作为首发提交物。
- 当前本地 Release build 是开发签名，不是最终提交物。
- 最终提交物必须验证 `get-task-allow = false`。
- 已移除 `network.server`、`files.user-selected.read-only`、`cs.allow-jit`；保留 `audio-input`。

### Phase F: 产品 QA

状态：部分自动化 QA 已完成；交互式产品 QA 待跑。

已自动覆盖：

- [x] `script/build_and_run.sh --verify`：构建并启动 Debug `Peek.app`，确认进程存在。
- [x] `script/qa_smoke.sh`：通过 Debug-only 通知展开真实面板，确认 Window Server 中存在 Peek 面板窗口。
- [x] `script/capture_app_store_screenshot.sh`：可启动并展开真实面板，当前会话在 `screencapture` 阶段因截图权限/会话状态失败。
- [x] `script/validate_app_store_materials.py`：验证三语言 App Store metadata 长度和禁用宣传词。
- [x] 搜索 URL 构造、空查询处理、查询 trim/encode。
- [x] URL 输入规范化：完整 URL、裸域名、localhost、普通搜索词。
- [x] 固定网站模型：id 生成、favicon fallback、custom favicon、Codable 还原。
- [x] Xcode unit test target 可通过 CLI 运行。

当前自动化限制：

- [ ] UI test runner 在当前 macOS 会话被系统认证状态阻塞，需要在干净用户会话或手动关闭系统认证提示后重跑。
- [ ] App Store 截图在当前 Codex/shell 会话被 Screen Recording/可见桌面状态阻塞；自动截图得到黑图，不能提交。
  - 可复跑命令：`./script/capture_app_store_screenshot.sh`

必须覆盖：

- [ ] 首次启动。
- [ ] 菜单栏图标点击。
- [ ] 菜单栏右键/control-click 菜单。
- [ ] 四个热角设置。
- [ ] 边缘面板唤出和自动收起。
- [ ] 固定面板行为。
- [ ] 面板尺寸调整。
- [ ] 搜索关键词。
- [ ] 直接输入 URL。
- [ ] 搜索建议。
- [ ] 新建标签页。
- [ ] 关闭标签页。
- [ ] 切换标签页。
- [ ] 固定网站添加。
- [ ] 固定网站打开。
- [ ] 固定网站移除。
- [ ] Launch at Login。
- [ ] App 语言切换：简体中文、英语、日语。
- [ ] WebKit 常见登录页面：
  - Google account page。
  - Slack。
  - Notion 或其他典型工作站点。
- [ ] 干净 macOS 用户环境测试。
- [ ] 无网络环境下基本界面表现。

### Phase G: GitHub Pages 部署

状态：已部署并通过公网验证。

本地已新增 workflow：

- `.github/workflows/pages.yml`

部署路径：

- Source directory: `CornerAssistantApp/landing-page`
- Production URL: `https://kaedeeeeeeeeee.github.io/cornor_assitant/`

上线步骤：

1. [x] 确认 landing 页面本地验证通过。
2. [x] commit 并 push 到 `main`。
3. [x] GitHub Pages 选择 GitHub Actions workflow build type。
4. [x] 触发 `Deploy Peek landing page` workflow。
5. [x] 打开 Actions logs，确认 artifact 上传和 deploy 成功。
6. [x] 验证公网 URL：

```bash
curl -I https://kaedeeeeeeeeee.github.io/cornor_assitant/
curl -I https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html
curl -I https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html
curl -I https://kaedeeeeeeeeee.github.io/cornor_assitant/robots.txt
curl -I https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml
```

### Phase H: App Review 和发布

状态：待 App Store Connect。

- [ ] 上传 build。
- [ ] 等待 build processing 完成。
- [ ] 选择 build 加入版本 `1.0`。
- [ ] 填完 metadata、截图、隐私、年龄分级、价格、可售区域。
- [ ] 检查所有链接都是公网 HTTPS 且返回 200。
- [ ] Submit for Review。
- [ ] 监控 App Review 消息。
- [ ] 如果被拒，复制完整 rejection text 到本项目文档或 issue，再做最小必要修复。
- [ ] 审核通过后选择发布模式：
  - Manual release：建议首发用这个，方便先改 landing CTA。
  - Automatic release。
  - Scheduled release。
- [ ] App Store 页面上线后更新：
  - Landing CTA 链接。
  - App Store URL 写回本计划。
  - Support page 如有必要加下载入口。

### Phase I: Post Launch

状态：待发布后执行。

- [ ] 验证 App Store 页面已公开。
- [ ] 验证 landing CTA 打开正确 App Store 页面。
- [ ] 验证 App Store Connect analytics 开始有数据。
- [ ] 验证 landing analytics 开始有数据。
- [ ] 提交 sitemap 后检查 Search Console index coverage。
- [ ] 搜索 `site:kaedeeeeeeeeee.github.io/cornor_assitant`，确认页面被收录。
- [ ] 记录首周用户反馈和崩溃日志。
- [ ] 准备 1.0.1 修复列表。

## 4. 仍然需要外部输入或后台操作的事项

这些不是代码里能自动完成的内容：

- [ ] GA4 Measurement ID。
  - GitHub Pages 已支持通过 repository variable `PEEK_GA_MEASUREMENT_ID` 注入；仍需真实 ID。
- [ ] Apple Developer/App Store Connect 登录权限。
- [ ] Xcode Settings > Accounts 中登录可用 Apple Developer 账号。
- [ ] Paid Apps Agreement、税务、银行信息。
- [ ] App Store Connect App record。
- [ ] Apple Developer PLA update acceptance。
- [ ] `com.shifeng.peek` App Store provisioning profile。
- [ ] App Store SKU 最终确认；建议 `peek-macos-001`。
- [ ] App Store 截图素材。
- [ ] App Review 真实联系电话。
- [ ] 如果包含 EU 地区：DSA trader status 和可公开联系信息。
- [ ] App Review release mode；建议首发使用 Manual release。
- [ ] 真实 Mac App Store URL。
- [ ] Google Search Console 所有权验证。
- [ ] Bing Webmaster Tools Microsoft 登录和站点提交。
- [x] GitHub Pages Settings 中启用 GitHub Actions Pages。

## 5. 文案红线

上线前所有公开文案必须遵守：

- 可以说：macOS 15.0+。
- 可以说：边缘/热角唤出。
- 可以说：快捷搜索、输入 URL、WebKit、标签页、固定网站。
- 可以说：App 不需要账号，偏好和固定站点保存在本地。
- 可以说：官网可能有 analytics。
- 不要说：macOS 14 支持。
- 不要说：选中文字搜索。
- 不要说：用户可选择 Google/Bing/搜索引擎。
- 不要说：App 内 analytics、云同步、账号、AI 功能、自动整理、OCR 等未验证功能。
- 不要把官网 analytics 写成 App 内数据收集。

## 6. 本地验收命令

Landing 本地预览：

```bash
cd CornerAssistantApp/landing-page
python3 -m http.server 4173
```

然后打开：

- `http://127.0.0.1:4173/`
- `http://127.0.0.1:4173/privacy.html`
- `http://127.0.0.1:4173/support.html`

Landing 必查项：

- [ ] 1440px 桌面首屏。
- [ ] 1024px tablet。
- [ ] 390px mobile。
- [ ] 三语切换。
- [ ] 页面没有水平滚动。
- [ ] App icon 加载。
- [ ] social preview image 加载。
- [ ] 访问 `robots.txt` 和 `sitemap.xml`。
- [ ] 控制台没有 JavaScript error。

App 本地构建：

```bash
cd CornerAssistantApp
xcodebuild \
  -project CornerAssistantApp.xcodeproj \
  -scheme CornerAssistantApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Release 构建：

```bash
cd CornerAssistantApp
xcodebuild \
  -project CornerAssistantApp.xcodeproj \
  -scheme CornerAssistantApp \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

发布前一键验证：

```bash
./script/launch_verify.sh
```

该脚本会执行 Release build、可自动运行的 XCTest、Release archive、归档 metadata/entitlements/privacy manifest 校验、Debug-only 字符串泄漏检查和公网 landing URL 检查。公网检查可用 `SKIP_NETWORK=1 ./script/launch_verify.sh` 跳过。

## 7. 当前下一步

按顺序执行：

1. 接受 Apple Developer Program License Agreement 更新。
2. 创建/刷新 `com.shifeng.peek` 的 App Store provisioning profile。
3. 用 Organizer 或 `xcodebuild -exportArchive` 重新执行 App Store export。
4. 验证 exported app entitlements 中 `get-task-allow = false`。
5. 在 App Store Connect 创建 Peek app record。
6. 填写 App Store Connect metadata、年龄分级、内容权利、App Privacy、审核备注和真实审核联系电话。
7. 如果覆盖 EU 地区，完成 DSA trader status；如果暂不覆盖 EU，先调整 availability。
8. 补 GA4 Measurement ID：在 GitHub repository variable 设置 `PEEK_GA_MEASUREMENT_ID`，或者明确首发先不开启 analytics。
9. 准备截图并上传 App Store metadata。
10. 在 Google Search Console / Bing Webmaster Tools 验证站点并提交 sitemap。
    - Search Console 当前需要为 `f.shera.09@gmail.com` 完成属性所有权验证。
    - Bing Webmaster Tools 当前需要 Microsoft 登录。
11. Upload build to App Store Connect。
12. 回填真实 App Store URL 到 landing CTA。
13. Submit for Review。

## 8. 参考链接

- Apple: Add a new app record - https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- Apple: Required, localizable, and editable properties - https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- Apple: Manage app privacy - https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple: Screenshot specifications - https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple: Upload builds - https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Apple: Sign and update agreements - https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/
- Apple: Set a price - https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/
- Apple: Set an app age rating - https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Apple: Provide Content Rights Information - https://developer.apple.com/help/app-store-connect/manage-app-information/provide-content-rights-information/
- Apple: Digital Services Act Compliance - https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- Google: SEO Starter Guide - https://developers.google.com/search/docs/fundamentals/seo-starter-guide
- Google: Sitemaps - https://developers.google.com/search/docs/crawling-indexing/sitemaps/overview
- Google: robots.txt - https://developers.google.com/search/docs/crawling-indexing/robots/intro
- Google: Canonical URLs - https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls
- Google: Software app structured data - https://developers.google.com/search/docs/appearance/structured-data/software-app
- Schema.org: SoftwareApplication - https://schema.org/SoftwareApplication
