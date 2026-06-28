# Corner Peek 上线准备计划

最后更新：2026-06-28 22:10 JST

这个文档是 Corner Peek 从当前本地项目走到公开 landing page 和 Mac App Store 首发的工作台。后续执行、验收、补漏都以这里为准；如果产品、定价、域名、隐私口径或 App Store 配置发生变化，先更新本文件，再改代码或页面。

## 0. 已确认决策

| 项目 | 决策 |
| --- | --- |
| App 名称 | Corner Peek |
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
- 当前 app 产品名为 Corner Peek，包名工程仍保留 `CornerAssistantApp` 命名。
- `SlidePanelView.swift` 当前直接使用 `GoogleSearchProvider()`；未使用的 `BingSearchProvider.swift` 已移除，Release archive 会检查 Bing provider/endpoint 字符串不得进入二进制。
- 当前代码没有系统选中文字读取逻辑；不能在 landing 或 App Store 文案中宣传 selected text search。未使用的 OCR history 残留已移除，Release archive 会检查 OCR history 字符串不得进入二进制。
- Landing 源设计来自 `/Users/user/Downloads/项目 Landing Page 设计.zip`，其中 `.dc.html` 是设计稿，不是生产站点。
- Landing 生产目录为 `CornerAssistantApp/landing-page`。
- App icon 已核对：`CornerAssistantApp/landing-page/assets/icon.png` 与 Xcode AppIcon 512@2x 像素一致，SHA-256 为 `1fdd1e4c18c4ce6bb80d1264807c8034c0af28a83aa9471a98a3d25a6ec436b0`，无需替换；`script/validate_app_icons.py` 已把该检查固化。
- `CornerAssistantApp/build/`、根目录 `build/`、`dist/`、历史 `.xcarchive`、`.dmg` 和构建日志都视为本地生成产物，不能提交 App Store Connect，也不能继续被 Git 跟踪；`script/validate_repository_hygiene.py` 已把该规则固化。

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
  - `CFBundleDisplayName = Corner Peek`
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
  - `NSMicrophoneUsageDescription = Websites opened in Corner Peek may request microphone access for features such as calls or voice input.`
- App Store 上架材料已重写：`CornerAssistantApp/docs/AppStore-Materials.md`。
- App Category 已设置为 `public.app-category.productivity`，避免 Xcode archive validation warning。
- 已新增 App Store export 配置：`CornerAssistantApp/export_options_app_store.plist`。
- App Store archive 已生成到 `/tmp/peek-appstore/Corner Peek.xcarchive`。
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
- `/tmp/peek-appstore/Corner Peek.xcarchive` 里的 archive app 已确认不含 `get-task-allow`，但 archive metadata 仍显示自动签名使用 `Apple Development`；最终提交物仍必须通过 App Store export/Organizer 重新签为 distribution。
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
- 2026-06-28 01:07 JST 再次执行 `xcodebuild -exportArchive`，失败原因仍为：
  - `error: exportArchive No Accounts`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
- 2026-06-28 01:26 JST 再次执行 `xcodebuild -exportArchive`，失败原因仍为：
  - `error: exportArchive No Accounts`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
- 2026-06-28 13:00 JST Apple Developer 后台状态更新：
  - 已接受最新 Apple Developer Program License Agreement；App Store Connect apps 列表不再显示协议更新横幅。
  - 已在 Certificates, Identifiers & Profiles 注册 `Corner Peek` / `com.shifeng.peek`，App ID Prefix 为 `Y4FV6WUU4V`。
  - 2026-06-28 15:25 JST 已创建 `Corner Peek` App Store Connect app record，app id 为 `6785167787`。
  - 仍需要创建/刷新 `com.shifeng.peek` 的 App Store provisioning profile，并让 Xcode/CLI 获得可用账号状态。

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
  - Archive 成功生成到 `/tmp/peek-appstore/Corner Peek.xcarchive`。
  - Archive Info.plist、entitlements、`PrivacyInfo.xcprivacy` 均已从归档产物中复核。

2026-06-27 自动化测试收口：

- 已新增 shared Xcode scheme：`CornerAssistantApp.xcodeproj/xcshareddata/xcschemes/CornerAssistantApp.xcscheme`。
- 已修复 `CornerAssistantAppTests` 的 `TEST_HOST`，从旧的 `CornerAssistantApp.app/CornerAssistantApp` 改为实际产物 `Corner Peek.app/Corner Peek`。
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
  - 启动 `DerivedData/CornerPeekRun/Build/Products/Debug/Corner Peek.app`。
  - 确认 `Corner Peek` 进程存在。
- 已新增 Debug-only 面板控制通知：
  - `com.shifeng.peek.debug.panelCommand`
  - 支持 `expand`、`collapse`、`toggle`。
  - 仅在 `#if DEBUG` 编译，不进入 Release/App Store 构建。
- 已新增 `script/qa_smoke.sh` 并验证通过：
  - 启动 Debug app。
  - 发送 debug `expand` 命令。
  - 从 Window Server 确认真实 Corner Peek 面板窗口可见。
  - 最近一次输出：`window id=8359 layer=3 bounds=["Y": 281, "Height": 750, "Width": 528, "X": 0]`。
- 自动截图尝试结果：
  - `screencapture` 产物为全黑图。
  - `screencapture -l` 对可见窗口返回 `could not create image from window`。
  - 当前 Codex/shell 会话不能作为 App Store 截图来源；需要在授予 Screen Recording 权限、可见桌面和干净测试环境中采集真实截图。
- Debug-only 面板命令加入后已重新验证：
  - Release build 成功。
  - `xcodebuild ... -skip-testing:CornerAssistantAppUITests test` 成功。
  - Release archive 成功生成到 `/tmp/peek-appstore/Corner Peek.xcarchive`。
  - Archive Info.plist、entitlements、`PrivacyInfo.xcprivacy` 均通过复核。
  - Release archive 可执行文件中未包含 `com.shifeng.peek.debug.panelCommand`。

2026-06-28 发布验证脚本收口：

- 已新增 `script/launch_verify.sh`，作为发布前一键 gate。
- 已新增 `script/validate_landing_public.py`，校验公网 landing 的 canonical、meta description、Open Graph/Twitter Card、`SoftwareApplication` JSON-LD、`robots.txt`、`sitemap.xml`、`site.webmanifest`、analytics config 和禁用宣传词。
- 已新增 `script/validate_landing_local.js`，启动本地静态服务并用 Playwright 校验 1440/1024/390 三个宽度、三语切换、无横向溢出、图片加载、隐私页、支持页和静态 SEO 文件。
- `script/launch_verify.sh` 已验证通过，覆盖：
  - App Store metadata 长度和禁用词校验。
  - Privacy/App Privacy 口径一致性校验。
  - 本地 landing UI/响应式/三语交互校验。
  - Release build。
  - 跳过 UI runner 的 XCTest。
  - Release archive。
  - Archive Info.plist 关键字段。
  - Archive entitlements。
  - Archive `PrivacyInfo.xcprivacy`。
  - Debug-only 面板命令和 hot corner smoke 命令没有进入 Release archive。
  - 公网 landing 关键 URL 均可达。
  - 公网 landing SEO 和 analytics config 校验。
  - 2026-06-28 01:36 JST 再次执行 `./script/launch_verify.sh`，通过。
  - 2026-06-28 01:48 JST 再次执行 `./script/launch_verify.sh`，通过。
  - 2026-06-28 02:04 JST 再次执行 `./script/launch_verify.sh`，通过。
  - 2026-06-28 02:13 JST 再次执行 `./script/launch_verify.sh`，通过。
  - 2026-06-28 02:28 JST 再次执行 `./script/launch_verify.sh`，通过。
  - 2026-06-28 02:42 JST 再次执行 `./script/launch_verify.sh`，通过；当前脚本已额外验证 App Store metadata 导出包。
  - 2026-06-28 02:50 JST 再次执行 `./script/launch_verify.sh`，通过；当前脚本已额外验证 screenshot `scenario:` 调试入口不进入 Release archive。
  - 2026-06-28 02:57 JST 再次执行 `./script/launch_verify.sh`，通过；当前测试已覆盖 status menu 结构、热角菜单项、语言菜单项和 Launch at Login 菜单标题。
  - 2026-06-28 03:11 JST 再次执行 `./script/launch_verify.sh`，通过；当前 readiness 脚本已额外覆盖 App Store export 成功后的 exported app metadata、privacy manifest 和 entitlements 验证。
  - 2026-06-28 03:17 JST 再次执行 `./script/launch_verify.sh`，通过；本轮仅更新计划文档和 QA 证据。
  - 2026-06-28 03:22 JST 再次执行 `./script/launch_verify.sh`，通过；当前测试已覆盖三语言切换和语言偏好持久化。
  - 2026-06-28 03:28 JST 再次执行 `./script/launch_verify.sh`，通过；当前测试已覆盖面板布局、固定防收起和外部点击自动收起策略。
  - 2026-06-28 03:32 JST 再次执行 `./script/launch_verify.sh`，通过；当前测试已覆盖 Launch at Login 管理逻辑。
  - 2026-06-28 03:36 JST 再次执行 `./script/launch_verify.sh`，通过；当前测试已覆盖 WebKit 登录兼容配置。

2026-06-28 Landing 本地验收收口：

- 已新增并验证 `script/validate_landing_local.js`。
- 本地脚本已覆盖：
  - 首页 1440px desktop、1024px tablet、390px mobile。
  - Privacy page desktop。
  - Support page desktop。
  - 三语切换：`zh`、`en`、`ja`。
  - 无横向溢出。
  - App icon 和页面图片加载正常。
  - `robots.txt`、`sitemap.xml`、`site.webmanifest`、`assets/social-preview.png` 可访问。
  - 无浏览器 console error。
- Atlas 浏览器也已打开 `http://127.0.0.1:4173/` 验证：当前页面 `title = Corner Peek - A Lightweight Browser from the macOS Screen Edge`，`lang = en`，`h1 = Out of sight. Right when you need it.`，图片正常，无横向溢出。

2026-06-28 截图采集脚本收口：

- 已新增 `script/capture_app_store_screenshot.sh`。
- 脚本默认输出到 `/tmp/peek-app-store-screenshots`，避免未审校截图直接进入仓库；需要保存到项目内时可设置 `OUT_DIR=CornerAssistantApp/docs/app-store-screenshots`。
- 脚本会：
  - 启动 Debug app。
  - 通过 Debug-only 通知展开真实 Corner Peek 面板。
  - 从 Window Server 定位 Corner Peek 面板窗口。
  - 用 `screencapture -l` 按窗口 ID 捕获。
  - 自动拒绝黑图/空图。
  - 生成 2880x1800 的 16:10 App Store 候选图。
- 2026-06-28 在当前 Codex/shell 会话运行结果：
  - 成功定位 Corner Peek 面板窗口：`window id=8433 bounds=0,281 528x750`。
  - 截图阶段失败：`could not create image from window`。
  - 结论：脚本可复跑，但当前会话仍缺少可用 Screen Recording/可见桌面截图能力；需要在已授权的可见桌面会话中重跑。
- 2026-06-28 01:26 JST 再次执行 `./script/capture_app_store_screenshot.sh`：
  - 成功定位 Corner Peek 面板窗口：`window id=8513 bounds=0,281 528x750`。
  - 截图阶段仍失败：`could not create image from window`。
  - 脚本提示需要给终端/Codex 宿主授予 Screen Recording 权限后重试。
- 2026-06-28 01:34 JST 已给 `script/capture_app_store_screenshot.sh` 增加 full-screen crop fallback：
  - 先尝试 `screencapture -x -l <window-id>`。
  - 如果窗口截图失败，则执行 `screencapture -x` 全屏截图，并按 Window Server 定位到的 Corner Peek 窗口坐标裁剪。
  - 当前会话复跑结果：窗口定位成功，fallback 生成 `peek-full-screen.png` 并裁剪出 `peek-panel-window.png`，但裁剪图仍被验证器判定为 blank/black。
  - 结论：脚本 fallback 已覆盖窗口级截图不稳定场景；当前仍缺 Screen Recording/可见桌面权限，不能产出可提交截图。
- 2026-06-28 02:50 JST 已把 `script/capture_app_store_screenshot.sh` 扩展为首发 5 张套件：
  - `01-hot-corner-panel-2880x1800.png`
  - `02-quick-search-2880x1800.png`
  - `03-web-page-2880x1800.png`
  - `04-tabs-and-pinned-sites-2880x1800.png`
  - `05-pinned-panel-2880x1800.png`
  - 仍保留兼容输出 `peek-panel-2880x1800.png`。
  - 这些截图场景通过 `#if DEBUG` notification 触发，`script/launch_verify.sh` 已验证 `scenario:` 调试命令不会进入 Release archive。
  - `script/check_external_readiness.py` 扩展模式现在会在截图脚本成功后验证 5 张 PNG 均为 2880x1800。
  - 当前扩展模式复查仍被 Screen Recording/可见桌面权限阻塞，不能产出可提交截图。
- 2026-06-28 22:00 JST 已把截图套件改成痛点型宣传截图：
  - 左侧为标题、说明文案和蓝色重点标注。
  - 右侧保留真实 Corner Peek 面板截图。
  - Debug 截图场景会临时使用无品牌 demo pinned sites，且不会写入用户偏好。
  - 5 张主题为 pinned daily tools、AI at the edge、docs/messages、trackers/sheets、web workflow。

2026-06-28 App Store metadata 校验收口：

- 已新增 `script/validate_app_store_materials.py`。
- 已修正三语言关键词，确保 App Store Connect keywords 字段不超过 100 bytes：
  - 中文关键词：98 bytes。
  - English keywords: 93 bytes。
  - 日本語キーワード：90 bytes。
- 当前 metadata 校验通过：
  - 基础信息表与已确认上线决策一致：App name、Bundle ID、SKU、价格、系统要求、support email、Marketing/Privacy/Support URL。
  - App name <= 30 chars。
  - Subtitle <= 30 chars。
  - Description <= 4000 chars。
  - Keywords <= 100 bytes。
  - What's New <= 4000 chars。
  - 未命中 `Bing`、`macOS 14`、`Sonoma`、selected text / 选中文字等禁用宣传词。
- `script/launch_verify.sh` 已纳入该校验。

2026-06-28 App Store metadata 导出包：

- 已新增 `script/export_app_store_metadata.py`。
- 已新增 `script/validate_app_store_metadata_export.py`。
- 默认导出目录：`/tmp/peek-app-store-metadata`。
- 导出前会先复用 `script/validate_app_store_materials.py` 校验，避免把超长字段或禁用宣传词复制进 App Store Connect。
- `script/validate_app_store_metadata_export.py` 会复查导出包文件集合、`app_information.json`、三语言 metadata、App Review notes、README 和 App Store Connect checklist，确保导出结果仍与 `CornerAssistantApp/docs/AppStore-Materials.md` 一致。
- 当前导出内容：
  - `app_information.json`：App record、价格、URL、隐私、年龄分级、出口合规和仍需手工填写的字段。
  - `app_store_connect_submission_checklist.md`：App Store Connect 表单照填清单，覆盖 app record、价格、年龄分级、内容权利、DSA、出口合规、截图计划和提交前核对。
  - `metadata/zh-Hans/`、`metadata/en-US/`、`metadata/ja/`：三语言 App name、subtitle、description、keywords、what's new。
  - `app_review_notes.txt`：审核备注草稿。
  - `README.md`：后台填写顺序和仍需手工完成的外部事项。
- 复跑命令：

```bash
./script/export_app_store_metadata.py
./script/validate_app_store_metadata_export.py
```

- 2026-06-28 01:42 JST 已执行通过，生成 `/tmp/peek-app-store-metadata`。
- 2026-06-28 02:41 JST 已重新执行通过，生成 `/tmp/peek-app-store-metadata/app_store_connect_submission_checklist.md`。
- 2026-06-28 04:19 JST 已用临时目录重新导出并通过内容一致性校验；`script/launch_verify.sh` 已纳入该校验。

2026-06-28 Privacy / App Privacy 口径校验收口：

- 已新增 `script/validate_privacy_alignment.py`。
- 当前自动校验覆盖：
  - `PrivacyInfo.xcprivacy` 只声明 UserDefaults required-reason API，reason 为 `CA92.1`。
  - `PrivacyInfo.xcprivacy` 中 `NSPrivacyTracking = false`，`NSPrivacyTrackingDomains = []`，`NSPrivacyCollectedDataTypes = []`。
  - Xcode Debug/Release build settings 中 sandbox、network client、audio input、incoming network、camera、location、user-selected files、JIT 和 export compliance 口径保持一致。
  - `NSMicrophoneUsageDescription` 与隐私文案一致：只有网站可能请求麦克风，Corner Peek 本身不录音。
  - `CornerAssistantApp/docs/AppStore-Materials.md` 中 App Privacy、Age Rating、Export Compliance、support email、macOS 15.0+ 和 App 内无 analytics SDK 的首发口径存在。
  - Landing privacy 文案中官网 analytics 明确限定为公开官网，不嵌入 macOS App。
- `script/launch_verify.sh` 已纳入该校验。

2026-06-28 QA 自动化覆盖扩展：

- 已新增：
  - `CornerAssistantAppTests/LaunchAtLoginManagerTests.swift`
  - `CornerAssistantAppTests/LaunchReadinessTests.swift`
  - `CornerAssistantAppTests/SlidePanelLayoutTests.swift`
  - `CornerAssistantAppTests/SlidePanelViewModelTests.swift`
  - `CornerAssistantAppTests/SuggestionStoreTests.swift`
  - `CornerAssistantAppTests/WebViewStoreTests.swift`
- `script/qa_smoke.sh` 已扩展：
  - 启动 Debug app 后先用 System Events 验证 Corner Peek status item 存在于菜单栏 accessibility tree。
  - 启动后用 Window Server 验证默认没有可见 Corner Peek 面板窗口。
  - 再用 Debug-only 通知逐个验证四个 hot corner 的真实面板窗口位置。
- 新增覆盖：
  - 首发三语言解析：`en`、`zh-Hans`、`ja`。
  - 三语言 `Localizable.strings` key 集合一致且值非空。
  - 首发关键 UI 文案 key 存在。
  - App 语言切换：`LocalizationManager` 可切换简体中文、日语、英语，切换后 bundle 文案更新，并写入 `CornerAssistantApp.PreferredLanguage`。
  - 四个 hot corner raw value 保持稳定。
  - 面板布局：保存尺寸 clamp、四个 hot corner hotspot rect、四个显示 frame、隐藏 frame 方向、可见高度限制。
  - 固定窗口/自动收起策略：未展开、正在 resize、窗口固定、点击窗口内都不会自动收起；未固定且点击窗口外会收起。
  - Launch at Login 管理逻辑：状态读取、注册、注销、同步委托，以及底层 ServiceManagement 错误不会逃逸到 UI 调用链。
  - WebKit 登录兼容配置：JavaScript popup、Safari-like user agent、navigation/UI delegate、back/forward gesture、Slack popup 同 WebView 打开策略。
  - 三语言 settings/language/hot corner 菜单文案存在。
  - Hot corner 默认值为 `bottomLeft`，保存/读取有效值正常，非法值会回退到默认值。
  - App Store 首发关键 build settings 保持一致：bundle id、product name、display name、AppIcon、Productivity 分类、version `1.0 (1)`、macOS 15.0。
  - 首发本地化文案不包含 `Bing`、selected text / 选中文字、`macOS 14`、`Sonoma` 等禁用宣传。
  - 搜索/URL 模型：空查询、trim、unicode 和符号查询、HTTP/HTTPS URL、裸域名、路径、localhost、普通搜索词。
  - 标签模型：新建、切换、关闭、关闭最后一个普通标签后自动补新 launcher tab。
  - 固定网站模型：打开、添加、移除、排序、重复 URL 防护、固定 tab 不被普通关闭、缺失 tab mapping 时创建新固定 tab。
  - 默认固定网站：ChatGPT、Notion、Slack 都是 HTTPS web destination。
  - 搜索建议模型：最小输入长度、debounce 后填充、clear。
- `xcodebuild ... -only-testing:CornerAssistantAppTests test` 已通过：
  - 2026-06-28 01:23 JST 通过。
  - 2026-06-28 01:47 JST `LaunchReadinessTests` 定向复跑通过。
  - 2026-06-28 03:21 JST `LaunchReadinessTests` 定向复跑通过；新增语言切换/持久化覆盖。
  - 2026-06-28 03:22 JST `xcodebuild ... -skip-testing:CornerAssistantAppUITests test` 通过。
  - 2026-06-28 03:27 JST `SlidePanelLayoutTests` 定向复跑通过；完整 unit test target 通过。
  - 2026-06-28 03:31 JST `LaunchAtLoginManagerTests` 定向复跑通过；完整 unit test target 通过。
  - 2026-06-28 03:35 JST `WebViewStoreTests` 定向复跑通过；完整 unit test target 通过。
  - 当前 `CornerAssistantAppTests` 共 52 个 `func test...`。
- `script/qa_smoke.sh` 已重新验证通过：
  - 当前 smoke 会先验证菜单栏 status item 存在。
  - 当前 smoke 会确认启动后默认没有可见 Corner Peek 面板窗口。
  - 当前 smoke 会逐个切换 Debug-only hot corner 命令并验证真实 Corner Peek 面板窗口位于对应屏幕边角。
  - 最近一次输出：
    - `status_item=title= description=Corner Peek x:1523 y:4 w:24 h:24`
    - `panel_hidden=true`
    - `corner=bottomLeft window id=8591 layer=3 bounds=x:0 y:281 width:528 height:750`
    - `corner=bottomRight window id=8591 layer=3 bounds=x:1186 y:271 width:528 height:750`
    - `corner=topLeft window id=8591 layer=3 bounds=x:14 y:43 width:528 height:750`
    - `corner=topRight window id=8591 layer=3 bounds=x:1186 y:43 width:528 height:750`
    - `qa_smoke passed`
- 2026-06-28 01:07 JST 再次执行 `xcodebuild -exportArchive`，失败原因仍为：
  - `error: exportArchive No Accounts`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
- 2026-06-28 01:26 JST 再次执行 `xcodebuild -exportArchive`，失败原因仍为：
  - `error: exportArchive No Accounts`
  - `error: exportArchive No profiles for 'com.shifeng.peek' were found`
- 2026-06-28 01:36 JST 再次执行 `./script/launch_verify.sh`，通过。
- 2026-06-28 01:48 JST 再次执行 `script/qa_smoke.sh` 和 `./script/launch_verify.sh`，均通过。
- 2026-06-28 02:04 JST 再次执行 `script/qa_smoke.sh` 和 `./script/launch_verify.sh`，均通过。
- 2026-06-28 02:06 JST 再次执行 `script/qa_smoke.sh`，通过。
- 2026-06-28 03:13 JST 再次执行 `script/qa_smoke.sh`，通过：
  - `status_item=title= description=Corner Peek x:1523 y:4 w:24 h:24`
  - `panel_hidden=true`
  - `corner=bottomLeft window id=8754 layer=3 bounds=x:0 y:281 width:528 height:750`
  - `corner=bottomRight window id=8754 layer=3 bounds=x:1186 y:271 width:528 height:750`
  - `corner=topLeft window id=8754 layer=3 bounds=x:14 y:43 width:528 height:750`
  - `corner=topRight window id=8754 layer=3 bounds=x:1186 y:43 width:528 height:750`
  - `qa_smoke passed`
- 2026-06-28 03:14 JST 尝试用 CGEvent 坐标点击和 System Events `click` 验证菜单栏左键；两者都能定位 status item，但未触发真实面板展开，因此菜单栏左键/右键仍保留为人工或更完整 UI automation 项。
- 2026-06-28 05:22 JST 复测 System Events `AXPress`：单独执行时可偶发触发展开，但在完整 smoke reset/expand 序列中不稳定，且 control-click/right-click 菜单仍不可稳定读取；不纳入 `script/qa_smoke.sh` 门禁。
- 2026-06-28 01:15 JST 再次执行 UI test target，失败原因仍为当前 macOS 会话认证状态：
  - `Failed to initialize for UI testing`
  - `System authentication is running`
- 2026-06-28 03:18 JST 再次执行 `xcodebuild -only-testing:CornerAssistantAppUITests test`，失败原因保持一致：
  - `Failed to initialize for UI testing`
  - `System authentication is running`
  - xcresult: `/Users/user/Library/Developer/Xcode/DerivedData/CornerAssistantApp-behwnokypyiqlsayqkbbnhyatybg/Logs/Test/Test-CornerAssistantApp-2026.06.28_03-18-50-+0900.xcresult`

2026-06-27 Export Compliance 收口：

- 已确认源码没有自研加密、CryptoKit、CommonCrypto、Security/SecKey/SecItem、OpenSSL/libsodium 等加密实现；网络访问来自 `URLSession`、WebKit 和系统框架。
- 已在主 app Debug/Release build settings 添加：
  - `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
- 已验证 Release build 成功。
- 已验证 unit tests 成功：
  - `xcodebuild -project CornerAssistantApp.xcodeproj -scheme CornerAssistantApp -destination 'platform=macOS' -skip-testing:CornerAssistantAppUITests test`
- 已重新生成 `/tmp/peek-appstore/Corner Peek.xcarchive`。
- Archive Info.plist 已确认：
  - `ITSAppUsesNonExemptEncryption = false`
- App Store Connect Export Compliance 建议按“不使用非豁免加密”填写；如果后续加入自研加密、VPN、端到端加密、密码管理、加密消息、加密文件存储或第三方加密库，必须重新评估。

## 1.2 本次部署记录

2026-06-27 已完成：

- GitHub Pages 已通过 GitHub REST API 启用为 workflow 模式。
- Pages HTTPS enforced。
- 已提交并推送 commit：`fff1270 launch: prepare Corner Peek landing and App Store release`。
- GitHub Actions workflow `Deploy Corner Peek landing page` 成功：
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
- GitHub Actions workflow `Deploy Corner Peek landing page` 成功：
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
- GitHub Actions workflow `Deploy Corner Peek landing page` 成功：
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
- 2026-06-28 03:39 JST 使用本机 Chrome + `npx lighthouse@latest` 复跑公网 desktop Lighthouse：
  - Performance: 95
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100
  - `color-contrast`、`document-title`、`meta-description`、`canonical`、`crawlable-anchors` 均通过。
- 2026-06-28 03:44 JST 已新增并运行 `script/check_landing_performance.py`：
  - PageSpeed Insights API desktop/mobile：HTTP 429 Too Many Requests，继续作为 manual / 非阻塞记录。
  - 本机 Chrome Lighthouse desktop：Performance 100、Accessibility 100、Best Practices 100、SEO 100。
  - Lighthouse JSON 产物：`/tmp/peek-lighthouse/public-desktop.json`。
- 2026-06-28 03:52 JST 已新增并运行 `script/validate_app_icons.py`：
  - `landing-page/assets/icon.png` 为 1024x1024。
  - Xcode AppIcon 512@2x 为 1024x1024，且与 landing icon SHA-256 完全一致。
  - `assets/social-preview.png` 为 1200x630。
  - `site.webmanifest` 中 `assets/icon.png` 尺寸声明已修正为 `1024x1024`。
- 2026-06-28 03:55 JST GitHub Pages workflow `28298609516` 成功；公网 `script/validate_landing_public.py` 通过：
  - 公网 `site.webmanifest` 中 `assets/icon.png` 声明为 `1024x1024`。
  - 公网 `assets/icon.png` 实际为 1024x1024。
  - 公网 `assets/social-preview.png` 实际为 1200x630。
  - 默认 readiness 结果为 `{"manual": 4, "ok": 9, "skipped": 2}`。
- 2026-06-28 04:01 JST 已移除未使用的 `BingSearchProvider.swift`，并在 `script/launch_verify.sh` 增加 Release archive guard：
  - `SKIP_NETWORK=1 ./script/launch_verify.sh` 通过。
  - `./script/qa_smoke.sh` 通过。
  - `/tmp/peek-appstore/Corner Peek.xcarchive/Products/Applications/Corner Peek.app/Contents/MacOS/Corner Peek` 未命中 `BingSearchProvider`、`bing.com` 或 `api.bing` 字符串。
- 2026-06-28 04:05 JST 已移除未使用的 `OCRHistoryManager.swift`，并在 `script/launch_verify.sh` 增加 Release archive guard：
  - `SKIP_NETWORK=1 ./script/launch_verify.sh` 通过。
  - Release archive 会拒绝 `OCRHistoryManager`、`OCRHistoryItem` 或 `OCRHistory` 字符串。
  - `/tmp/peek-appstore/Corner Peek.xcarchive/Products/Applications/Corner Peek.app/Contents/MacOS/Corner Peek` 未命中 `OCRHistoryManager`、`OCRHistoryItem`、`OCRHistory`、`BingSearchProvider`、`bing.com` 或 `api.bing` 字符串。
- 2026-06-28 04:08 JST 已新增 `script/validate_release_archive_strings.py`，并将 Release archive 字符串检查从 `launch_verify.sh` 的 inline grep 收口为独立校验：
  - `SKIP_NETWORK=1 ./script/launch_verify.sh` 通过。
  - 校验 executable 不含 Debug-only panel command、Debug hot corner/scenario command、Bing provider/endpoint、OCR history 残留。
  - 校验 archive 内三语言 `Localizable.strings` 不含 `Bing`、selected-text search、`macOS 14`、`Sonoma` 等禁用公开文案。
- 2026-06-28 04:11 JST 已强化权限/entitlement gate：
  - `script/validate_privacy_alignment.py` 现在会检查 Xcode build settings 中 `YES`/`NO` 相反值不得同时存在。
  - `script/launch_verify.sh` 现在会把 archive entitlements 和 allowlist 精确对比；当前只允许 `app-sandbox`、`network.client`、`audio-input`。
  - `SKIP_NETWORK=1 ./script/launch_verify.sh` 通过。
- 2026-06-28 04:14 JST 已新增 `script/validate_export_options.py` 并接入 `script/launch_verify.sh`：
  - 校验 `CornerAssistantApp/export_options_app_store.plist` 为 App Store Connect export。
  - 当前配置：`method = app-store-connect`、`signingCertificate = Apple Distribution`、`signingStyle = automatic`、`stripSwiftSymbols = true`、`uploadSymbols = true`、`teamID = Y4FV6WUU4V`。
  - `SKIP_NETWORK=1 ./script/launch_verify.sh` 通过。
- 首页 JSON-LD `applicationCategory` 已从 `UtilitiesApplication` 调整为 `Productivity`，与 App Store 分类保持一致。

2026-06-28 01:24 JST GitHub Pages / analytics 复查：

- `gh auth status` 显示当前 GitHub CLI 已登录 `Kaedeeeeeeeeee`。
- `gh api repos/Kaedeeeeeeeeee/cornor_assitant/pages` 确认：
  - `build_type = workflow`
  - `html_url = https://kaedeeeeeeeeee.github.io/cornor_assitant/`
  - `cname = null`
- `gh run list --workflow pages.yml --limit 5` 最近 3 次 workflow 都是 `success`。
- `gh api repos/Kaedeeeeeeeeee/cornor_assitant/actions/variables` 返回 `total_count = 0`；当前未设置 `PEEK_GA_MEASUREMENT_ID`、`PEEK_GOOGLE_SITE_VERIFICATION`、`PEEK_BING_SITE_VERIFICATION`。

2026-06-28 外部依赖状态脚本收口：

- 已新增 `script/check_external_readiness.py`，用于复查 GitHub Pages、公网 URL、官网 analytics config、Google/Bing verification meta、GitHub Actions variables、App Store export 和截图权限状态。
- 默认模式不触发 export 或截图，只做只读检查：
  - `./script/check_external_readiness.py`
  - 最近输出摘要：`{"manual": 4, "ok": 9, "skipped": 2}`。
- 扩展模式会额外复查 App Store export 和截图权限：
  - `PEEK_CHECK_EXPORT=1 PEEK_CHECK_SCREENSHOT=1 ./script/check_external_readiness.py`
  - 最近输出摘要：`{"blocked": 2, "manual": 4, "ok": 9}`。
  - 当前 blocked 项：`app_store_export` 仍为 `No Accounts / no com.shifeng.peek App Store profile`；`app_store_screenshot_capture` 仍为 Screen Recording/window capture permission 不可用。
  - 当前 manual 项：`PEEK_GA_MEASUREMENT_ID`、`PEEK_GOOGLE_SITE_VERIFICATION`、`PEEK_BING_SITE_VERIFICATION` 未设置；公网首页暂无 `google-site-verification` / `msvalidate.01` meta。
- 2026-06-28 01:42 JST 复查结果保持一致：
  - 默认模式：`{"manual": 2, "ok": 9, "skipped": 2}`。
  - 扩展模式：`{"blocked": 2, "manual": 2, "ok": 9}`。
- 2026-06-28 01:48 JST 扩展模式复查结果保持一致：`{"blocked": 2, "manual": 2, "ok": 9}`。
- 2026-06-28 02:04 JST 扩展模式复查结果保持一致：`{"blocked": 2, "manual": 2, "ok": 9}`。
- 2026-06-28 02:11 JST 脚本已扩展 Google/Bing verification meta 检查：
  - 默认模式：`{"manual": 4, "ok": 9, "skipped": 2}`。
- 2026-06-28 02:13 JST 扩展模式复查结果：`{"blocked": 2, "manual": 4, "ok": 9}`。
- 2026-06-28 已新增 `script/configure_landing_variables.sh`：
  - dry-run 已验证会校验并列出将设置的 variable 名称，不打印 token 值。
  - 无效 GA4 ID 会失败，避免写入错误 repository variable。
  - 2026-06-28 02:28 JST 已验证脚本语法、dry-run、错误 token 拦截和默认 readiness 检查。
  - 2026-06-28 04:27 JST 已扩展 `--rerun-pages --check-after`：真实触发 Pages workflow 后会等待新 run 完成，再运行 `script/check_external_readiness.py`，避免部署尚未完成时误判公网状态。
- 2026-06-28 已新增 `script/configure_app_store_url.py`：
  - dry-run 已验证会接受 `https://apps.apple.com/.../app/.../id...` 格式并列出将更新的文件。
  - 无效 host 会失败，避免把非 App Store 链接写入 landing CTA。
  - `script/validate_landing_local.js` 已扩展 CTA 状态校验：disabled CTA 必须保持 `href="#"` / `aria-disabled="true"` / `is-disabled`，active CTA 必须指向 `https://apps.apple.com/` 且不能保留 coming-soon 文案。
- 2026-06-28 02:18 JST Pages workflow `28296237761` 成功；公网 `script/validate_landing_public.py` 通过；默认 readiness 结果为 `{"manual": 4, "ok": 9, "skipped": 2}`。
- 2026-06-28 03:12 JST 默认 readiness 复查结果保持一致：`{"manual": 4, "ok": 9, "skipped": 2}`。
- 2026-06-28 03:12 JST `PEEK_CHECK_EXPORT=1 ./script/check_external_readiness.py` 复查结果：`{"blocked": 1, "manual": 4, "ok": 9, "skipped": 1}`；blocked 项仍为 `No Accounts / no com.shifeng.peek App Store profile`。
- 2026-06-28 03:14 JST `PEEK_CHECK_SCREENSHOT=1 ./script/check_external_readiness.py` 复查结果：`{"blocked": 1, "manual": 4, "ok": 9, "skipped": 1}`；blocked 项仍为 Screen Recording/window capture permission 不可用。
- 2026-06-28 04:22 JST 已新增 `script/validate_pages_workflow.py` 并纳入 `script/launch_verify.sh`：
  - 校验 GitHub Pages workflow 触发路径、Pages 权限、部署 action、artifact 目录和 GitHub repository variables 名称。
  - 校验 workflow 对 GA4 Measurement ID、Google/Bing verification token 的格式 guard、HTML attribute escaping 和空 token no-op 逻辑。
  - 拒绝把 landing 配置误接到 secrets、硬编码示例 GA4 ID 或旧版 deploy-pages action。
- 2026-06-28 04:23 JST `script/check_external_readiness.py` 已增加 Pages stale deploy 判断：
  - 如果最近一次成功 Pages run 不是当前 HEAD，会检查自该 run 以来是否有 `CornerAssistantApp/landing-page/**` 或 `.github/workflows/pages.yml` 变更。
  - 当前结果：最近一次 Pages run 成功，且之后没有 landing/page workflow 变更，所以公网部署不视为陈旧。
- 2026-06-28 04:34 JST 已收窄地址栏 URL 规范化：
  - 显式 URL 只允许 `http://` 和 `https://` 直接进入 WebView。
  - `ftp://`、`peek://`、`file://` 等非 Web scheme 已由 `SearchProviderTests` 覆盖为拒绝。
  - `SearchProviderTests` 和 `SKIP_NETWORK=1 ./script/launch_verify.sh` 均通过。
- 2026-06-28 04:37 JST 已新增 `script/validate_app_store_urls.py` 并纳入 `script/launch_verify.sh`：
  - 离线模式校验 App Store materials 中 Marketing / Privacy Policy / Support URL 与已确认生产 URL 一致，且均为 HTTPS GitHub Pages URL。
  - 联网模式额外请求三条 URL 并要求 HTTP 200。
- 2026-06-28 04:43 JST 已新增 `script/validate_repository_hygiene.py` 并纳入 `script/launch_verify.sh`：
  - `.gitignore` 现在明确忽略 `/build/`、`/dist/`、`*.dmg`、`*.xcarchive/`、`CornerAssistantApp/build/` 和 `CornerAssistantApp/*.log`。
  - 已从 Git 跟踪中移除 369 个历史 build/archive/dmg/log 生成文件；本地文件保留，仅不再进入仓库。
  - 当前 `git ls-files` 中生成产物数量为 0，`script/validate_repository_hygiene.py` 通过。
- 2026-06-28 04:49 JST 已通过 `script/configure_landing_variables.sh --rerun-pages --check-after` 设置 Google Search Console verification variable，并触发 Pages workflow：
  - Pages workflow `28299926702` 成功。
  - 公网首页已出现 `google-site-verification` meta。
  - `script/check_external_readiness.py` 默认结果更新为 `{"manual": 3, "ok": 10, "skipped": 2}`；剩余 manual 为 GA4、Bing verification 和缺少对应 GitHub variables。
- 2026-06-28 04:58 JST 复查：
  - 默认 readiness 仍为 `{"manual": 3, "ok": 10, "skipped": 2}`。
  - 扩展 readiness 仍为 `{"blocked": 2, "manual": 3, "ok": 10}`，blocked 项为 App Store export 账号/profile 和截图权限。
  - `script/check_landing_performance.py`：PageSpeed desktop/mobile 仍为 HTTP 429，本机 Lighthouse desktop 仍为 Performance 100、Accessibility 100、Best Practices 100、SEO 100。
  - Google Analytics 已登录并可读到账号 `ZHANG SHIFENG`、属性 `とりあえずこの名前使う`，但页面提示该属性没有 data stream，因此还没有可用 GA4 Measurement ID。
- 2026-06-28 05:03 JST 已强化 sitemap 可抓取性校验：
  - `script/validate_landing_public.py` 现在会分别用默认 UA、Googlebot UA、Bingbot UA 拉取并解析 sitemap。
  - `script/check_external_readiness.py` 现在会输出 `googlebot_sitemap_fetch` 和 `bingbot_sitemap_fetch`。
  - 当前公网 sitemap 对 Googlebot/Bingbot 均返回 HTTP 200，且都能解析到 3 个预期 URL。
  - 默认 readiness 更新为 `{"manual": 3, "ok": 12, "skipped": 2}`。
- 2026-06-28 05:10 JST 复查和本机 QA：
  - Google Analytics 仍显示当前属性没有 data stream；未创建 Web data stream，仍没有 GA4 Measurement ID。
  - Google Search Console sitemap 表格仍显示 `/sitemap.xml` 状态为“取得できませんでした”；机器校验仍证明公网 sitemap 对搜索 bot 可抓取。
  - Bing Webmaster Tools 仍无已登录会话；未选择身份提供方，未提交站点。
  - App Store Connect 仍跳转到 `authResult=FAILED` 登录入口；CLI export 仍为 `No Accounts / no com.shifeng.peek App Store profile`，notarytool 也无凭据。
  - `./script/qa_smoke.sh` 已通过，覆盖菜单栏 status item、面板默认隐藏和四个角落面板定位。
  - `script/check_external_readiness.py` 已新增 `PEEK_CHECK_QA_SMOKE=1` 可选检查，用于复跑本机菜单栏/面板 smoke QA。
  - 默认 readiness 当前为 `{"manual": 3, "ok": 12, "skipped": 3}`；`PEEK_CHECK_QA_SMOKE=1` 扩展 readiness 当前为 `{"manual": 3, "ok": 13, "skipped": 2}`。
- 2026-06-28 05:22 JST 本机菜单栏点击复测：
  - `./script/qa_smoke.sh` 稳定通过，继续覆盖菜单栏 status item 存在性、面板默认隐藏和四个角落真实窗口定位。
  - System Events `AXPress` 复测可偶发触发 status item 左键展开，但在完整 smoke reset/expand 序列中不稳定；未纳入自动发布门禁。
  - control-click/right-click 菜单在当前会话仍不可稳定读取，菜单栏左键 toggle 和右键菜单仍保留为人工或更完整 UI automation 项。
- 2026-06-28 05:26 JST 人工 QA 清单收口：
  - 已新增 `CornerAssistantApp/docs/Manual-QA-Checklist.md`，把首次启动、菜单栏点击/右键菜单、热角、resize、搜索/URL、固定网站、Launch at Login、WebKit 登录页、无网络、截图和人工证据整理成可执行 checklist。
  - 已新增 `script/validate_manual_qa_checklist.py` 并纳入 `script/launch_verify.sh`，防止发布计划里的人工作业清单缺失关键项。
  - `script/export_app_store_metadata.py` 现在会把 `manual_qa_checklist.md` 一并放入 `/tmp/peek-app-store-metadata`；`script/validate_app_store_metadata_export.py` 会验证导出副本和源码清单一致。
- 2026-06-28 05:31 JST 外部输入清单收口：
  - 已新增 `CornerAssistantApp/docs/External-Launch-Inputs.md`，把 GA4、Search Console/Bing、Apple Developer/App Store Connect、provisioning/export/upload、截图、审核电话、DSA 和最终 App Store URL 拆成明确需要用户或账号持有人处理的输入项。
  - 已新增 `script/validate_external_launch_inputs.py` 并纳入 `script/launch_verify.sh`，确保外部输入清单不会遗漏关键阻塞项。
  - `script/export_app_store_metadata.py` 现在会把 `external_launch_inputs.md` 一并放入 `/tmp/peek-app-store-metadata`；`script/validate_app_store_metadata_export.py` 会验证导出副本和源码清单一致。
- 2026-06-28 05:37 JST App Store 签名资产复查细化：
  - `script/check_external_readiness.py` 现在默认只读检查 Apple Distribution identity 和本机 provisioning profile。
  - 当前本机已安装 `Apple Distribution` identity for team `Y4FV6WUU4V`。
  - 当前本机没有 `com.shifeng.peek` 的 App Store provisioning profile；同 team 下只发现 `Notation Mac App Store (Y4FV6WUU4V.com.shifengzhang.notation)`。
  - 默认 readiness 当前为 `{"manual": 4, "ok": 13, "skipped": 3}`；新增 manual 项是缺少 Corner Peek App Store profile。
- 2026-06-28 05:45 JST 浏览器和外部 readiness 复查：
  - 内置浏览器可读 Google Search Console：`/sitemap.xml` 行仍显示类型 `不明`、提交日期 `2026/06/28`、状态 `取得できませんでした`、发现页面数 `0`；详情页显示 `サイトマップを読み込めませんでした`。
  - 公网 `sitemap.xml` 当前仍为 HTTP 200，`content-type: application/xml`，默认 UA、Googlebot UA、Bingbot UA 均能解析到 3 个预期 URL。
  - Google Analytics 仍可读账号 `ZHANG SHIFENG` / 属性 `とりあえずこの名前使う`，页面提示 `データ ストリームが見つかりませんでした`，没有 `G-...` Measurement ID；创建 Web data stream 属于后台写操作，需 action-time 确认或用户自行创建。
  - Bing Webmaster Tools 当前仍是未登录公开介绍页，显示 `Sign In` / `Get started`。
  - App Store Connect 当前仍停在 Apple Account 邮箱/密码登录页，URL 为 `https://appstoreconnect.apple.com/login?targetUrl=%2Fapps&authResult=FAILED`。
  - `PEEK_CHECK_QA_SMOKE=1 ./script/check_external_readiness.py` 单独顺序复跑通过，结果为 `{"manual": 4, "ok": 14, "skipped": 2}`；不要把截图 readiness 和 QA smoke 作为并行进程同时运行，否则两个检查都会启动 Debug Corner Peek 并干扰窗口判定。
- 2026-06-28 15:45 JST 发布资产复查：
  - App Store Connect app record 已存在：`Corner Peek` / app id `6785167787`。
  - Apple Developer profile 创建表单已准备好：类型 `Mac App Store Connect`，App ID `Peek (Y4FV6WUU4V.com.shifeng.peek)`，证书 `SHIFENG ZHANG (Distribution)`，名称 `Corner Peek Mac App Store`；下一步点击 `Generate` 前需要账号持有人确认。
  - `/tmp/peek-appstore/Corner Peek.xcarchive` 已复核：`com.shifeng.peek`、`1.0 (1)`、universal `x86_64` + `arm64`、`LSMinimumSystemVersion = 15.0`、`public.app-category.productivity`、`ITSAppUsesNonExemptEncryption = false`、PrivacyInfo 无 collected data、entitlements 为 App Sandbox/network client/audio input。
  - `/tmp/peek-app-store-metadata` 已按当前文档重新导出并通过 `./script/validate_app_store_metadata_export.py`。
  - `PEEK_CHECK_SCREENSHOT=1 PEEK_CHECK_QA_SMOKE=1 ./script/check_external_readiness.py` 通过截图和 QA 扩展检查，结果为 `{"manual": 4, "ok": 15, "skipped": 1}`；已生成 5 张 2880x1800 App Store 候选截图到 `/tmp/peek-app-store-screenshots`。
- 2026-06-28 18:00 JST App Store profile 和 export 收口：
  - 已在 Apple Developer 创建并下载 `Corner Peek Mac App Store` provisioning profile，UUID `725ce297-837d-47df-b5ec-1593515efaac`，App ID `Y4FV6WUU4V.com.shifeng.peek`，过期日 `2027/05/17`。
  - 已安装到 `~/Library/MobileDevice/Provisioning Profiles/725ce297-837d-47df-b5ec-1593515efaac.provisionprofile`。
  - `export_options_app_store.plist` 已切到 manual signing，显式配置 `provisioningProfiles` 和 `installerSigningCertificate = 3rd Party Mac Developer Installer`。
  - `PEEK_CHECK_EXPORT=1 ./script/check_external_readiness.py` 通过，导出并验证 `/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`，包内 app Info.plist、entitlements 和 PrivacyInfo 均通过检查。
  - `pkgutil --check-signature` 确认导出 pkg 使用 `3rd Party Mac Developer Installer: SHIFENG ZHANG (Y4FV6WUU4V)` 签名。
  - 2026-06-28 20:33 JST `xcrun altool --validate-app` 通过，验证文件为 `/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`。
  - 2026-06-28 20:35 JST `xcrun altool --upload-package` 上传成功，Delivery UUID 为 `1381454e-1354-4bf6-9ad9-b89482779afe`。
  - `xcrun altool --build-status --delivery-id 1381454e-1354-4bf6-9ad9-b89482779afe` 返回 `build-status = VALID`、`import-status = VALID`、`buildAudienceType = APP_STORE_ELIGIBLE`。
- 2026-06-28 22:10 JST App Store Connect 表单推进：
  - Version page 已保存 English (U.S.)、Chinese (Simplified)、Japanese metadata。
  - Build `1.0 (1)` 已加入 version `1.0`。
  - App Review contact、notes、support URL、marketing URL、copyright 和 manual release 已保存。
  - App Information 已保存三语言 subtitle、Productivity 分类、Content Rights。
  - Age Ratings 已保存；因 Unrestricted Web Access，Apple calculated rating 为 `16+`。
  - App Privacy 已发布为 `Data Not Collected`，Privacy Policy URL 指向公网 privacy page。
  - Pricing 已设置 United States (USD) `$5.99`，Availability 已设置 All Countries or Regions / 175 countries or regions。
  - App Accessibility 未填写；当前未做 VoiceOver/Larger Text 等逐项验收，不应过度声明。
  - 截图已上传：Chrome connector 的 file chooser 被权限拒绝后，2026-06-28 22:35 JST 改用 Computer Use 和 macOS file picker 上传 5 张正式 PNG；App Store Connect 显示 `5 of 10 Screenshots`。

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
- [x] 本地响应式和三语交互已纳入 `script/validate_landing_local.js`。
- [x] 增加 Privacy Policy 页面。
- [x] 增加 Support 页面。
- [x] 增加 landing-only analytics loader。
- [ ] 配置真实 GA4 Measurement ID。
  - 当前 loader 已就绪，但默认不加载任何 analytics。
  - 拿到 ID 后用 `script/configure_landing_variables.sh` 设置 GitHub repository variable `PEEK_GA_MEASUREMENT_ID`，然后手动 rerun `Deploy Corner Peek landing page` workflow 或加 `--rerun-pages`。
  - 2026-06-28 01:24 JST 通过 GitHub API 复查：repository actions variables 为空，`PEEK_GA_MEASUREMENT_ID` 仍未设置。
  - 2026-06-28 04:58 JST Google Analytics 只读复查：当前账号 `ZHANG SHIFENG`、属性 `とりあえずこの名前使う` 已存在，但没有 data stream；创建 Web data stream 后才能得到 `G-...` Measurement ID。创建 data stream 会改动 Google Analytics 账号配置，需行动前确认。
- [x] 增加 GitHub Pages Actions workflow。
- [x] 在 GitHub 仓库中启用 GitHub Actions Pages 发布源。
- [x] 合并/推送后验证 Pages 公网 URL。
- [ ] App Store URL 出来后，把 CTA 从 “Coming soon” 改成真实链接。
  - 已新增 `script/configure_app_store_url.py`；拿到真实 `https://apps.apple.com/.../app/.../id...` URL 后先 dry-run，再写入 landing 并运行本地校验。

### Phase B: SEO 基础

状态：本地基础、公网验证、Lighthouse 和 Google Search Console 所有权验证已完成；Google sitemap 处理状态待复查；Bing Webmaster Tools 待登录。

- [x] 设置 canonical host：`https://kaedeeeeeeeeee.github.io/cornor_assitant/`。
- [x] 首页、隐私页、支持页设置独立 title 和 meta description。
- [x] 增加 Open Graph 和 Twitter Card metadata。
- [x] 增加 `SoftwareApplication` JSON-LD。
  - `applicationCategory = Productivity`
- [x] 增加 `site.webmanifest`。
  - `assets/icon.png` 声明为 `1024x1024`，与真实 PNG 尺寸一致。
- [x] 增加 `robots.txt`。
- [x] 增加 `sitemap.xml`。
- [x] 生成 `assets/social-preview.png`。
- [x] GitHub Pages workflow 支持搜索引擎所有权验证 meta 注入：
  - Google Search Console：GitHub repository variable `PEEK_GOOGLE_SITE_VERIFICATION`。
  - Bing Webmaster Tools：GitHub repository variable `PEEK_BING_SITE_VERIFICATION`。
  - token 只在部署产物中注入，不写死到仓库源码。
- [x] 增加 GitHub landing variables 配置脚本：
  - `script/configure_landing_variables.sh`
  - 支持 `PEEK_GA_MEASUREMENT_ID`、`PEEK_GOOGLE_SITE_VERIFICATION`、`PEEK_BING_SITE_VERIFICATION`。
  - 支持 `--dry-run`、`--rerun-pages`、`--check-after`。
- [x] 部署后检查：
  - 首页、隐私页、支持页返回 200。
  - `robots.txt` 返回 200。
  - `sitemap.xml` 返回 200。
  - 社交卡片图片返回 200。
  - App Store materials 中 Marketing / Privacy Policy / Support URL 均为公网 HTTPS 且返回 200。
  - canonical URL 和最终 Pages URL 一致。
  - 页面没有 `noindex`。
- [x] Google Search Console 所有权验证。
  - 2026-06-28 04:50 JST 使用 `f.shera.09@gmail.com` 通过 HTML tag 方式完成验证。
- [x] Google Search Console sitemap URL 已提交。
  - 已提交 `https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml`。
  - Search Console 弹窗显示“サイトマップを送信しました”。
  - 即时表格状态仍为“取得できませんでした / サイトマップを読み込めませんでした”；公网和 Googlebot UA 访问该 sitemap 均返回 200，后续需要在 Search Console 复查处理状态。
  - 2026-06-28 04:56 JST 复查结果未变化：Search Console 仍显示 `/sitemap.xml` 状态为“取得できませんでした”。
  - 2026-06-28 05:03 JST 机器校验确认：默认 UA、Googlebot UA、Bingbot UA 均可 HTTP 200 拉取 sitemap，并解析到首页、隐私页、支持页 3 个 URL；当前问题保留为 Search Console 处理状态待复查。
- [ ] Bing Webmaster Tools 提交。
  - 2026-06-28 04:52 JST Bing Webmaster Tools 仍停留在未登录页；点击 Sign In 后只出现 Microsoft/Google/Facebook 登录选项，没有现成 Microsoft 会话。未使用 Google 身份登录 Bing。
- [x] 部署后跑 Lighthouse，记录性能和 SEO 分数。
- [x] 将公网 landing SEO 校验纳入 `script/launch_verify.sh`。
- [x] 增加 landing 性能复查脚本：
  - `script/check_landing_performance.py`
  - 默认调用 PageSpeed Insights API 和本机 Chrome Lighthouse。
  - PageSpeed API 配额或 429 只记为 manual；本机 Lighthouse 低于阈值才使脚本失败。
- [x] 增加外部依赖状态脚本：
  - `script/check_external_readiness.py`
  - 默认复查公网 URL、GitHub Pages、GitHub Actions variables、analytics config 和 Google/Bing verification meta。
  - 可用 `PEEK_CHECK_EXPORT=1 PEEK_CHECK_SCREENSHOT=1` 额外复查 App Store export 和截图权限。
- [ ] PageSpeed Insights 在线报告可后续补充，不阻塞首发。
  - 2026-06-28 通过 PageSpeed Insights API 请求移动端/桌面端报告时返回 HTTP 429 Too Many Requests；本项继续作为非阻塞补充项。
  - 2026-06-28 03:39 JST 复查 PageSpeed Insights API，desktop/mobile 仍返回 HTTP 429 Too Many Requests；公网 Lighthouse 已复跑并通过。
  - 2026-06-28 03:44 JST 使用 `script/check_landing_performance.py` 复查，PageSpeed API desktop/mobile 仍返回 HTTP 429 Too Many Requests；本机 Chrome Lighthouse desktop 为 100/100/100/100。

搜索引擎提交说明：

- `robots.txt` 已公开声明 sitemap：`https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml`。
- Google Search Console 已用 `f.shera.09@gmail.com` 完成所有权验证；不要删除部署产物中的 `google-site-verification` meta。
- Search Console 已提交 sitemap，但当前显示无法读取；后续先复查处理状态，不要重复提交旧式匿名 sitemap ping。
- Bing Webmaster Tools 仍需要登录 Microsoft 账号后提交站点和 sitemap；不要使用旧式匿名 sitemap ping 端点作为上线证据。
- 提交 Bing sitemap 会改变站长工具账号状态，执行前需要确认使用哪个 Microsoft 账号。
- 拿到验证 token 后，用 `script/configure_landing_variables.sh` 设置 GitHub repository variables：
  - `PEEK_GOOGLE_SITE_VERIFICATION`：Google meta tag 的 `content` 值。
  - `PEEK_BING_SITE_VERIFICATION`：Bing `msvalidate.01` meta tag 的 `content` 值。
  - 推荐命令：

```bash
PEEK_GOOGLE_SITE_VERIFICATION=... \
PEEK_BING_SITE_VERIFICATION=... \
  ./script/configure_landing_variables.sh --rerun-pages --check-after
```

  - 脚本会校验 token 格式，不在日志里打印 token 值。设置后运行 `./script/check_external_readiness.py` 复查 meta 是否出现在公网首页。

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
- 当前 Apple 后台阻塞仍以 `xcodebuild -exportArchive` 的直接错误为准：本机 Xcode/CLI 没有可用账号，且没有 `com.shifeng.peek` App Store provisioning profile。登录账号后仍需检查是否有 Apple Developer PLA 更新待接受。

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

2026-06-28 00:36 JST 后台可达性复查：

- App Store Connect agreements：
  - `https://appstoreconnect.apple.com/agreements/` 最终仍跳转到 `https://appstoreconnect.apple.com/login?targetUrl=/agreements/`。
  - 当前无可操作 App Store Connect 登录会话，无法读取或接受协议。
- Google Search Console：
  - 当前仍登录 `f.shera.09@gmail.com`，但 `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 属性未验证。
  - 页面仍显示“このプロパティへのアクセス権がありません”和“所有権を証明”；点击验证入口在当前浏览器自动化会话中仍超时，未提交验证。
- Bing Webmaster Tools：
  - 当前仍为公开未登录页，页面显示 Sign In / Get started；未提交站点。

2026-06-28 01:16 JST 后台可达性复查：

- App Store Connect agreements：
  - `https://appstoreconnect.apple.com/agreements/` 最终仍跳转到 `https://appstoreconnect.apple.com/login?targetUrl=/agreements/`。
  - 当前无可操作 App Store Connect 登录会话。
- Google Search Console：
  - 当前登录账号仍为 `f.shera.09@gmail.com`。
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 属性仍未验证，页面标题为“このプロパティへのアクセス権がありません”。
- Bing Webmaster Tools：
  - 当前仍跳转到公开介绍页 `https://www.bing.com/webmasters/about?...`，页面显示 Sign In / Get started；未登录，未提交站点。
- PageSpeed Insights API：
  - mobile 和 desktop 请求仍返回 HTTP 429 Too Many Requests；继续作为非阻塞补充项。
  - 2026-06-28 03:39 JST 复查结果保持一致；改用本机 Chrome + Lighthouse 复核公网性能和 SEO。

2026-06-28 04:53 JST 后台可达性复查：

- App Store Connect:
  - `https://appstoreconnect.apple.com/apps` 跳转到 `https://appstoreconnect.apple.com/login?targetUrl=%2Fapps&authResult=FAILED`。
  - 当前无可操作 App Store Connect 登录会话；页面停在 Apple Account 邮箱/密码登录表单，未提交任何表单。
- Google Search Console:
  - 当前浏览器已登录 `f.shera.09@gmail.com`。
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 属性已通过 HTML tag 方式验证成功，页面显示“所有権を証明しました”。
  - 已提交 `sitemap.xml`；详情 URL 确认为 `https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml`。
  - Search Console 即时状态为“サイトマップを読み込めませんでした”；CLI 复查同一 URL 对 Googlebot UA 返回 200，需后续复查 Google 处理状态。
- Bing Webmaster Tools:
  - 当前仍为公开未登录页；Sign In 只显示 Microsoft/Google/Facebook 登录选项，没有可用登录会话。
  - 未用 Google 身份登录 Bing，未提交站点。

2026-06-28 04:58 JST 后台可达性复查：

- Google Search Console:
  - `https://kaedeeeeeeeeee.github.io/cornor_assitant/` 属性仍可访问。
  - sitemap 表格仍显示 `/sitemap.xml`、提交日期 `2026/06/28`、状态“取得できませんでした”、发现页面数 `0`。
- Google Analytics:
  - 已登录 Google Analytics。
  - 当前账号为 `ZHANG SHIFENG`，当前属性为 `とりあえずこの名前使う`。
  - 页面提示“データ ストリームが見つかりませんでした”，即该属性没有 data stream；没有读取到 GA4 Measurement ID。
  - 未点击“ウェブ”创建数据流，未修改 GA 配置。
- App Store Connect / Bing Webmaster Tools:
  - 本轮未发现新的可用登录会话；仍需用户登录/确认后继续。

2026-06-28 05:10 JST 后台可达性复查：

- Google Analytics:
  - 当前页面仍提示“データ ストリームが見つかりませんでした”，没有读取到 `G-...` Measurement ID。
  - 未点击“ウェブ”创建数据流，未修改 GA 配置。
- Google Search Console:
  - sitemap 页面仍显示 `/sitemap.xml`、提交日期 `2026/06/28`、状态“取得できませんでした”、发现页面数 `0`。
  - 机器校验继续确认 `https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml` 对默认 UA、Googlebot UA、Bingbot UA 均返回 HTTP 200 且包含 3 个预期 URL。
- Bing Webmaster Tools:
  - 当前仍为公开未登录页；未进入已登录站点管理页，未提交站点。
- App Store Connect:
  - `https://appstoreconnect.apple.com/apps` 仍跳转到 `https://appstoreconnect.apple.com/login?targetUrl=%2Fapps&authResult=FAILED`。
  - `PEEK_CHECK_EXPORT=1 ./script/check_external_readiness.py` 仍显示 App Store export 被 `No Accounts / no com.shifeng.peek App Store profile` 阻塞。

2026-06-27 App Store Connect 表单材料补齐：

- `CornerAssistantApp/docs/AppStore-Materials.md` 已补充可照填字段：
  - App record。
  - Pricing and Availability。
  - Age Rating 问卷建议。
  - Content Rights / Third-Party Content。
  - App Review Information。
  - EU DSA / Trader Status 准备项。
- 年龄分级关键口径：
  - Corner Peek 是 browser-like WebKit app，用户可以输入 URL、搜索或打开固定网站。
  - `Unrestricted Web Access` 必须按真实能力填写 `Yes`。
  - App 本身不内置暴力、色情、赌博、医疗、UGC、广告或原生聊天内容。
  - 最终年龄分级由 App Store Connect 根据问卷自动计算；不要在公开文案里承诺更低年龄分级。
- 内容权利关键口径：
  - Corner Peek 不打包、镜像、缓存或再分发第三方内容。
  - 第三方网页只在用户主动输入 URL、搜索、点击结果或打开固定网站时访问。
  - App 自带素材、icon、landing 文案和截图应确保归开发者所有或已授权。

- [ ] Apple Developer Program 账号可用。
- [ ] Paid Apps Agreement 已签署。
- [ ] Apple Developer Program License Agreement 更新已接受。
- [ ] 税务和银行信息已配置，否则 US$5.99 付费销售无法上线。
- [x] 创建 macOS App 记录：
  - Name: Corner Peek
  - Bundle ID: `com.shifeng.peek`
  - SKU: `corner-peek-macos-001`
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
5. 固定面板状态；如果后续手动采集菜单栏状态截图，也可以替换该图。

截图要求：

- 使用干净桌面和真实 app build。
- 不出现开发工具、测试数据、个人隐私信息。
- 不展示未实现功能。
- 尽量覆盖中文、英文或日文中的至少一种主语言；如果 App Store Connect 支持本地化截图，后续再补全三语。
- 当前机器已有 `/Applications/Corner Peek.app` 运行；为避免干扰用户当前桌面，本次没有自动控制该实例采集截图。
- 当前自动化会话已能用 `script/qa_smoke.sh` 展开真实 Debug 面板，但 `screencapture` 在该会话下只能得到黑图，不能作为 App Store 截图素材。
- 已新增 `script/capture_app_store_screenshot.sh` 作为可复跑截图入口；脚本支持窗口截图和 full-screen crop fallback，并会生成 5 张 2880x1800 首发候选图。当前会话运行到截图验证阶段仍被 Screen Recording/可见桌面权限阻塞。
- 建议截图采集方式：
  - 在可见干净桌面中授予当前终端/Codex 宿主 Screen Recording 权限。
  - 先运行 `./script/capture_app_store_screenshot.sh` 采集 Debug 面板候选图；脚本会拒绝黑图并生成 5 张 2880x1800 PNG。
  - 如果需要严格使用 distribution build，再使用 `/tmp/peek-appstore/Corner Peek.xcarchive/Products/Applications/Corner Peek.app` 或最终 exported app 手动采集。
  - 在干净桌面/测试用户中打开 app。
  - 用菜单栏图标或热角展示面板。
  - 只截取 app 窗口或经过清理的完整桌面。
  - 采集完成后保存到 `CornerAssistantApp/docs/app-store-screenshots/` 或外部素材目录，再决定是否提交进仓库。
- Mac App Store 官方接受 16:10 截图：1280x800、1440x900、2560x1600、2880x1800；建议首发使用 2880x1800 或 2560x1600。

### Phase E: App Build Readiness

状态：本地 Release build、archive、App Store distribution export、altool validation 和 App Store Connect upload 均已通过；下一步是在 App Store Connect 选择 build 并补齐提交资料。

- [x] 明确当前 dirty worktree 哪些是本次上线工作，哪些是用户已有改动。
- [x] 确认版本号：
  - `MARKETING_VERSION = 1.0`
  - `CURRENT_PROJECT_VERSION` 每次上传递增。
- [x] 确认 bundle metadata：
  - Bundle ID: `com.shifeng.peek`
  - Display name: `Corner Peek`
  - Minimum macOS version: 15.0
  - Copyright: `© 2026 Zhang Shifeng`
  - `ITSAppUsesNonExemptEncryption = false`
- [x] 确认 App Sandbox entitlement。
- [x] 确认 WebKit 浏览需要的 network client entitlement。
- [x] 检查是否真的需要 audio input entitlement；保留给 WebKit 页面请求麦克风，Info.plist 和 privacy copy 已同步。
- [x] 确认 archive app entitlements 没有 `com.apple.security.get-task-allow`。
  - `script/launch_verify.sh` 会精确校验 archive entitlement allowlist：`com.apple.security.app-sandbox`、`com.apple.security.network.client`、`com.apple.security.device.audio-input`。
- [x] 确认最终 App Store exported app 没有 `com.apple.security.get-task-allow`。
  - `script/check_external_readiness.py` 已扩展：App Store export 成功后会定位 exported `.app`，验证 bundle metadata、`PrivacyInfo.xcprivacy`、sandbox/network/audio entitlements，并拒绝 `com.apple.security.get-task-allow`。
- [x] 确认 `PrivacyInfo.xcprivacy` 已加入 target 并打包进 app。
- [x] 确认 app icon 和 bundle icon 使用真实 Corner Peek icon。
  - 自动覆盖：`script/validate_app_icons.py` 验证 AppIcon 全尺寸 PNG、landing icon、manifest icon 声明、social preview 尺寸和 landing 页面 icon/social image 引用。
- [x] 确认 menu bar icon 在真实运行环境中显示正常。
  - `script/qa_smoke.sh` 已用 System Events 验证 Corner Peek status item 存在于菜单栏 accessibility tree。
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
  -archivePath /tmp/peek-appstore/Corner Peek.xcarchive \
  -allowProvisioningUpdates
```

- [x] 用 Xcode Organizer 或 `xcodebuild -exportArchive` 走 App Store distribution。
  - 已新增 `export_options_app_store.plist`。
  - `script/validate_export_options.py` 已覆盖 export options：App Store Connect method、Apple Distribution certificate、manual signing、Corner Peek App Store profile、Mac installer signing certificate、symbols 配置和 10 位 Apple team ID。
  - 2026-06-28 18:00 JST `PEEK_CHECK_EXPORT=1 ./script/check_external_readiness.py` 已通过，导出 `/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`。
- [x] 发布前一键验证脚本：

```bash
./script/launch_verify.sh
```

  - 2026-06-28 01:36 JST 已通过。
- [x] 上传 App Store Connect：
  - 2026-06-28 20:35 JST 已用 `xcrun altool --upload-package` 上传 `/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`。
  - Delivery UUID：`1381454e-1354-4bf6-9ad9-b89482779afe`。
  - build status：`VALID` / `APP_STORE_ELIGIBLE`。

注意：

- Mac App Store 提交重点是 App Store 签名和 App Store Connect 上传；独立分发才强依赖 notarization。不要把普通本地 debug 和分发签名问题混在一起判断。
- 历史 `CornerAssistantApp/build/` 和 `.xcarchive` 只作为参考，不能作为首发提交物。
- 当前本地 Release build 是开发签名，不是最终提交物。
- 最终提交物必须验证 `get-task-allow = false`。
- 已移除 `network.server`、`files.user-selected.read-only`、`cs.allow-jit`；保留 `audio-input`。

### Phase F: 产品 QA

状态：部分自动化 QA 已完成；交互式产品 QA 待跑。

已自动覆盖：

- [x] `script/build_and_run.sh --verify`：构建并启动 Debug `Corner Peek.app`，确认进程存在。
- [x] `script/qa_smoke.sh`：通过 Debug-only 通知展开真实面板，确认 Window Server 中存在 Corner Peek 面板窗口。
  - 当前也覆盖菜单栏 status item 存在性。
  - 当前也覆盖启动后默认无可见面板窗口。
  - 当前覆盖四个 hot corner 的真实窗口定位。
- [x] `script/capture_app_store_screenshot.sh`：可启动并展开真实面板，可生成 5 张首发截图套件；当前会话在 `screencapture` 阶段因截图权限/会话状态失败。
- [x] `script/validate_app_store_materials.py`：验证三语言 App Store metadata 长度和禁用宣传词。
- [x] `script/validate_app_store_urls.py`：验证 App Store Connect 要填写的 Marketing / Privacy Policy / Support URL 与生产公网 URL 一致，并可联网要求 HTTP 200。
- [x] `script/export_app_store_metadata.py`：导出可复制进 App Store Connect 的三语言 metadata、基础字段、审核备注和提交表单清单材料包。
- [x] `script/validate_app_store_metadata_export.py`：验证生成后的 metadata 导出包文件集合和内容与 `AppStore-Materials.md`、`Manual-QA-Checklist.md`、`External-Launch-Inputs.md` 保持一致。
- [x] `script/validate_export_options.py`：验证 App Store Connect export options 配置。
- [x] `script/validate_privacy_alignment.py`：验证 PrivacyInfo、Xcode 权限、App Store App Privacy 口径和 landing privacy 文案一致；同时拒绝 Xcode build settings 中出现相反权限值。
- [x] `script/validate_manual_qa_checklist.py`：验证人工 QA 清单包含首发真实交互、截图、证据记录和当前人工阻塞项。
- [x] `script/validate_external_launch_inputs.py`：验证外部账号、后台操作、截图、审核电话、DSA、GA4/Bing 和最终 App Store URL 输入清单完整。
- [x] `script/validate_landing_public.py`：验证公网 landing SEO、sitemap、manifest、icon/social preview 尺寸、analytics config 和禁用宣传词。
  - 当前也覆盖默认 UA、Googlebot UA、Bingbot UA 的 sitemap 抓取与 URL 解析。
- [x] `script/validate_pages_workflow.py`：验证 GitHub Pages workflow 会正确注入 landing analytics / site verification variables，并部署 `CornerAssistantApp/landing-page`。
- [x] `script/validate_app_icons.py`：验证 Xcode AppIcon、landing icon、web manifest icon 和 social preview 尺寸/一致性。
- [x] `script/validate_release_archive_strings.py`：验证 Release archive executable 和三语言资源不包含调试入口、未发布功能残留或禁用公开文案。
- [x] `script/validate_repository_hygiene.py`：验证 build/archive/dmg/log 等生成产物没有被 Git 跟踪，并确认 `.gitignore` 保持对应规则。
- [x] `script/check_external_readiness.py`：复查公网 URL、GitHub Pages/variables、GA4 配置状态，并可选复查 export/截图权限阻塞。
  - 当前也覆盖 App Store export 成功后的 exported app metadata、privacy manifest 和 entitlements 验证。
  - 当前也覆盖最近一次成功 Pages run 是否仍覆盖当前 landing/page workflow 变更。
  - 当前也覆盖 Googlebot/Bingbot sitemap 抓取与 URL 解析，用于区分 Search Console 后台处理状态和真实公网可抓取性。
  - 当前也可通过 `PEEK_CHECK_QA_SMOKE=1` 复跑菜单栏 status item、面板默认隐藏和四角面板定位 smoke QA。
- [x] `script/configure_app_store_url.py`：真实 App Store URL 出来后激活 landing CTA、更新三语言 CTA 文案和 JSON-LD，并复跑本地 landing 校验。
- [x] 搜索 URL 构造、空查询处理、查询 trim/encode。
- [x] URL 输入规范化：完整 HTTP/HTTPS URL、裸域名、路径、localhost、普通搜索词；非 Web scheme 不从地址栏直接打开。
- [x] 搜索建议模型：最小输入长度、debounce、clear。
  - 当前也覆盖 suggestions 请求失败或无网络时清空旧建议，不保留 stale results。
- [x] 标签模型：新建、切换、关闭、关闭最后普通标签后自动补新 launcher tab、排序。
- [x] 固定网站模型：id 生成、favicon fallback、custom favicon、Codable 还原。
- [x] 固定网站 view model：添加、打开、移除、排序、重复 URL 防护、固定 tab 关闭保护。
- [x] 首发三语言 key 集合一致、关键 UI 文案存在、settings/language/hot corner 菜单文案存在、hot corner 选项稳定。
- [x] Status menu 结构：热角子菜单、Launch at Login、语言子菜单、退出项、四个热角选项和三种语言选项均有测试覆盖。
- [x] Hot corner 默认值、保存/读取和非法值回退。
- [x] App Store 首发 build settings：bundle id、product/display name、AppIcon、Productivity 分类、version `1.0 (1)`、macOS 15.0。
- [x] 本地化文案不包含 `Bing`、selected text / 选中文字、`macOS 14`、`Sonoma` 等禁用宣传。
- [x] 四个热角设置：Debug smoke 已验证真实面板窗口落在对应屏幕边角。
- [x] Xcode unit test target 可通过 CLI 运行。
- [x] Debug screenshot 场景入口不会进入 Release archive。
- [x] 未使用的 Bing 搜索 provider 不进入 Release archive。
- [x] 未使用的 OCR history 残留不进入 Release archive。

当前自动化限制：

- [ ] UI test runner 在当前 macOS 会话被系统认证状态阻塞，需要在干净用户会话或手动关闭系统认证提示后重跑。
  - 2026-06-28 05:10 JST 单独运行 UI launch test 仍失败：`Authentication canceled. System authentication is running.`
- [x] App Store 截图候选图已在当前 Codex/shell 会话生成。
  - 2026-06-28 15:45 JST `PEEK_CHECK_SCREENSHOT=1 PEEK_CHECK_QA_SMOKE=1 ./script/check_external_readiness.py` 通过截图权限和 QA smoke 检查。
  - 已生成 `/tmp/peek-app-store-screenshots/01-hot-corner-panel-2880x1800.png` 至 `05-pinned-panel-2880x1800.png`，全部为 2880x1800。
  - 2026-06-28 22:00 JST 已重新生成痛点型宣传截图，视觉快检通过：文案未溢出，面板清晰，未出现第三方品牌 logo。
  - 上传前仍需在 App Store Connect 截图排序页面做最终人工审校。

必须覆盖：

- [ ] 首次启动。
  - 2026-06-28 05:10 JST 已通过 `./script/qa_smoke.sh` 自动确认 Debug app 启动后进程存在、菜单栏 status item 存在、面板默认隐藏；完整首启体验仍需人工跑。
- [ ] 菜单栏图标点击。
  - 2026-06-28 已确认 status item 存在；05:22 JST 复测 `AXPress` 可偶发触发展开，但在完整 smoke 序列中不稳定，本项仍需手动或更完整 UI automation 验证。
- [ ] 菜单栏右键/control-click 菜单。
  - 2026-06-28 05:22 JST 复测后仍无法在当前会话稳定读取弹出菜单，本项仍需手动或更完整 UI automation 验证。
- [x] 四个热角设置。
  - 自动覆盖：`LaunchReadinessTests` 验证四个 hot corner raw value、菜单文案、默认值和持久化；`script/qa_smoke.sh` 验证四个 hot corner 对应的真实面板窗口定位。
- [ ] 边缘面板唤出和自动收起。
  - 自动覆盖了 Debug expand/collapse、四角定位、hotspot rect、隐藏/显示 frame 和外部点击自动收起策略；2026-06-28 05:10 JST `./script/qa_smoke.sh` 已通过四角真实窗口定位。真实鼠标边缘触发仍需人工或更完整 UI automation。
- [x] 固定面板行为。
  - 自动覆盖：`SlidePanelLayoutTests.testGlobalMouseDownCollapsePolicyRespectsPinnedAndResizingStates` 验证固定状态下点击外部不会自动收起，未固定且点击外部会收起。
- [ ] 面板尺寸调整。
  - 自动覆盖：`SlidePanelLayoutTests` 验证保存尺寸 clamp 和显示高度不会超过可见区域；真实拖拽 resize 仍需人工或更完整 UI automation。
- [x] 搜索关键词。
  - 自动覆盖：`SearchProviderTests` 验证空查询、trim、unicode/符号查询和 Google search URL 构造。
- [x] 直接输入 URL。
  - 自动覆盖：`SearchProviderTests` 验证 HTTP/HTTPS、裸域名、路径、localhost 和普通搜索词区分。
- [x] 搜索建议。
  - 自动覆盖：`SuggestionStoreTests` 验证最小输入长度、debounce、clear，以及请求失败/无网络时清空旧建议。
- [x] 新建标签页。
- [x] 关闭标签页。
- [x] 切换标签页。
  - 自动覆盖：`SlidePanelViewModelTests` 验证新建、切换、关闭、关闭最后普通标签后的 replacement launcher tab。
- [x] 固定网站添加。
- [x] 固定网站打开。
- [x] 固定网站移除。
  - 自动覆盖：`SlidePanelViewModelTests` 和 `PinnedSiteTests` 验证 pinned site 添加、打开、移除、排序、重复 URL 防护、固定 tab 关闭保护和 favicon fallback。
- [ ] Launch at Login。
  - 自动覆盖：`LaunchAtLoginManagerTests` 验证 `SMAppService` 包装层的状态读取、注册、注销、同步委托和错误吞吐；真实系统登录项注册仍需在干净 macOS 用户会话里人工确认。
- [x] App 语言切换：简体中文、英语、日语。
  - 自动覆盖：`LaunchReadinessTests.testLocalizationManagerSwitchesAndPersistsLaunchLanguages` 验证三语言切换、bundle 文案更新和偏好持久化。
- [ ] WebKit 常见登录页面：
  - Google account page。
  - Slack。
  - Notion 或其他典型工作站点。
  - 自动覆盖：`WebViewStoreTests` 验证 Safari-like user agent、JavaScript popup、delegate、back/forward gesture，以及 Slack popup 同 WebView 打开策略；真实 Google/Slack/Notion 登录页仍需可见桌面人工实测。
- [ ] 干净 macOS 用户环境测试。
- [ ] 无网络环境下基本界面表现。
  - 2026-06-28 已自动覆盖搜索建议请求失败路径；完整无网络 WebKit 页面表现仍需在干净用户会话人工确认。

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
4. [x] 触发 `Deploy Corner Peek landing page` workflow。
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

状态：build 已上传并加入版本；App Store Connect 核心 metadata、隐私、价格、可售区域、年龄分级和 5 张截图已保存；待最终预览审校并提交审核。

- [x] 上传 build。
  - 已上传导出包：`/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`
  - Delivery UUID：`1381454e-1354-4bf6-9ad9-b89482779afe`
- [x] 等待 build processing 完成。
  - `build-status = VALID`
  - `import-status = VALID`
  - `buildAudienceType = APP_STORE_ELIGIBLE`
- [x] 选择 build 加入版本 `1.0`。
- [x] 填完 metadata、隐私、年龄分级、价格、可售区域。
- [x] 上传 App Store screenshots。
  - 当前本地素材：`/tmp/peek-app-store-screenshots/01-hot-corner-panel-2880x1800.png` 至 `05-pinned-panel-2880x1800.png`。
  - 2026-06-28 22:35 JST 已通过 Computer Use 和 macOS file picker 上传到 App Store Connect；页面显示 `5 of 10 Screenshots`。
  - 2026-06-28 22:00 JST 本地截图素材已更新为新痛点型宣传图；App Store Connect 需要在用户确认后删除旧图并重新上传新图。
  - 提交审核前仍需人工确认 App Store Connect 页面预览顺序和缩略图渲染。
- [x] 检查所有链接都是公网 HTTPS 且返回 200。
  - `script/validate_app_store_urls.py --check-network` 已验证 App Store materials 中 Marketing / Privacy Policy / Support URL 均为 HTTPS 且返回 200。
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
  - Google Analytics 已有账号/属性，但没有 data stream；创建 Web data stream 后才能获得 Measurement ID。
  - 2026-06-28 05:45 JST 浏览器复查确认 landing GA4 首发启用决策已定，但后台仍缺 Web data stream / Measurement ID。
- [ ] Apple Developer/App Store Connect 登录权限。
- [ ] Xcode Settings > Accounts 中登录可用 Apple Developer 账号。
- [ ] Paid Apps Agreement、税务、银行信息。
- [x] App Store Connect App record。
  - 2026-06-28 15:25 JST 已创建 `Corner Peek` macOS app record，App Store Connect app id 为 `6785167787`。
- [x] Apple Developer PLA update acceptance。
  - 2026-06-28 13:00 JST 已接受；App Store Connect 不再显示协议更新横幅。
- [x] Apple Developer Bundle ID / App ID。
  - 2026-06-28 13:00 JST 已注册 `Corner Peek` / `com.shifeng.peek`，App ID Prefix 为 `Y4FV6WUU4V`。
- [x] Apple Distribution certificate installed.
  - 2026-06-28 05:37 JST `script/check_external_readiness.py` 确认 team `Y4FV6WUU4V` 的 Apple Distribution identity 已安装。
- [x] `com.shifeng.peek` App Store provisioning profile。
  - 2026-06-28 05:37 JST 本机仅发现同 team 的 `Notation` App Store profile，未发现 `com.shifeng.peek` profile。
  - 2026-06-28 13:00 JST Identifier 已存在，可继续创建/刷新 App Store profile。
  - 2026-06-28 15:45 JST Apple Developer profile 创建表单已填好并停在 `Generate` 前；等待账号持有人确认生成。
  - 2026-06-28 17:49 JST 已生成并安装 `Corner Peek Mac App Store` profile；`script/check_external_readiness.py` 默认检查已识别到 1 个 matching App Store profile。
- [x] App Store SKU 最终确认：`corner-peek-macos-001`。
- [x] App Store 截图候选素材。
- [x] App Store 截图已上传。
- [x] App Review 真实联系电话。
- [ ] 如果包含 EU 地区：DSA trader status 和可公开联系信息。
- [x] App Review release mode：Manual release。
- [ ] 真实 Mac App Store URL。
- [x] Google Search Console 所有权验证。
- [ ] Google Search Console sitemap 处理状态复查。
  - sitemap 已提交，但当前 Search Console 显示“无法读取”；公网 URL 对 Googlebot UA 返回 200。
  - 2026-06-28 05:45 JST 详情页仍显示 `サイトマップを読み込めませんでした`，公网 `sitemap.xml` 仍为 HTTP 200 / `application/xml`。
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

- [x] 1440px 桌面首屏。
- [x] 1024px tablet。
- [x] 390px mobile。
- [x] 三语切换。
- [x] 页面没有水平滚动。
- [x] App icon 加载。
- [x] social preview image 加载。
- [x] 访问 `robots.txt` 和 `sitemap.xml`。
- [x] 控制台没有 JavaScript error。

自动验收：

```bash
./script/validate_landing_local.js
```

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

该脚本会执行 repository hygiene 校验、App Store metadata 校验、App Store URL 校验、App Store metadata 导出包校验、App Store export options 校验、Privacy/App Privacy 口径一致性校验、人工 QA 清单校验、外部输入清单校验、本地 landing 校验、GitHub Pages workflow 校验、App icon/landing icon 一致性校验、Release build、可自动运行的 XCTest、Release archive、归档 metadata/entitlements/privacy manifest 校验、archive entitlement allowlist、Release archive 字符串检查、公网 landing URL 检查和公网 landing SEO/analytics config 校验。公网检查可用 `SKIP_NETWORK=1 ./script/launch_verify.sh` 跳过。

App Store Connect metadata 导出：

```bash
./script/export_app_store_metadata.py
```

默认输出到 `/tmp/peek-app-store-metadata`。登录 App Store Connect 并创建 app record 后，从该目录复制三语言 metadata、审核备注、基础字段、`app_store_connect_submission_checklist.md` 里的后台表单清单、`manual_qa_checklist.md` 的人工 QA 清单，以及 `external_launch_inputs.md` 的外部输入清单；截图、真实联系电话、价格层级确认、DSA 和 build selection 仍需在后台手工完成。

Landing repository variables 配置：

```bash
PEEK_GA_MEASUREMENT_ID=G-... \
PEEK_GOOGLE_SITE_VERIFICATION=... \
PEEK_BING_SITE_VERIFICATION=... \
  ./script/configure_landing_variables.sh --dry-run
```

确认输出无误后去掉 `--dry-run`，可追加 `--rerun-pages --check-after` 触发 Pages workflow，等待新 run 完成，并复查公网状态。脚本只设置非空变量，会验证格式，并且不会在日志里打印 token 值。

App Store URL 回填：

```bash
PEEK_APP_STORE_URL=https://apps.apple.com/.../app/.../id... \
  ./script/configure_app_store_url.py --dry-run
```

确认输出无误后去掉 `--dry-run`。脚本会要求 URL 使用 `https://apps.apple.com`、包含 `/app/` 和 `/id...`，然后激活首页两个 Mac App Store CTA、更新三语言 CTA 文案、写入 JSON-LD `installUrl` / offer URL，并运行 `script/validate_landing_local.js`。

外部依赖状态复查：

```bash
./script/check_external_readiness.py
PEEK_CHECK_QA_SMOKE=1 ./script/check_external_readiness.py
PEEK_CHECK_EXPORT=1 PEEK_CHECK_SCREENSHOT=1 ./script/check_external_readiness.py
```

默认模式只读，不触发 App Store export、截图或本机 UI 控制；当前也会读取本机 code signing identity 和 provisioning profile，拆分证书/profile 状态。扩展模式会写入 `/tmp/peek-appstore/external-readiness-export`、启动截图脚本或启动 Debug app smoke QA，用于复查账号/profile、Screen Recording 权限和本机菜单栏/面板 QA 是否已经解除或仍通过。

UI 类扩展检查需要顺序执行，不要在多个 shell 里并行运行 `PEEK_CHECK_SCREENSHOT=1` 和 `PEEK_CHECK_QA_SMOKE=1`；两者都会启动 Debug Corner Peek，重复实例会干扰窗口隐藏/定位断言。

Landing 性能复查：

```bash
./script/check_landing_performance.py
```

默认会请求 PageSpeed Insights desktop/mobile，并用本机 Chrome + `npx lighthouse@latest` 生成公网 desktop Lighthouse 报告到 `/tmp/peek-lighthouse/public-desktop.json`。PageSpeed 429 或配额问题只作为 manual 状态记录；Lighthouse 分数低于阈值会使脚本失败。

## 7. 当前下一步

按顺序执行：

1. 创建/刷新 `com.shifeng.peek` 的 App Store provisioning profile。
2. 用 Organizer 或 `xcodebuild -exportArchive` 重新执行 App Store export。
3. 验证 exported app entitlements 中 `get-task-allow = false`。
4. 运行 `./script/export_app_store_metadata.py`，从 `/tmp/peek-app-store-metadata` 复制 metadata 和审核备注。
5. 填写 App Store Connect 年龄分级、内容权利、App Privacy、真实审核联系电话和其他后台表单。
6. 如果覆盖 EU 地区，完成 DSA trader status；如果暂不覆盖 EU，先调整 availability。
7. 补 GA4 Measurement ID：
   - 现有 Google Analytics 账号/属性为 `ZHANG SHIFENG` / `とりあえずこの名前使う`，但没有 data stream。
   - 确认后在该属性下创建 Web data stream：URL `https://kaedeeeeeeeeee.github.io/cornor_assitant/`，stream name 建议 `Corner Peek Landing Page`。
   - 拿到 `G-...` 后用 `script/configure_landing_variables.sh` 设置 `PEEK_GA_MEASUREMENT_ID`，或者明确首发先不开启 analytics。
8. 准备截图并上传 App Store metadata。
   - 2026-06-28 22:35 JST 已完成；App Store Connect 显示 `5 of 10 Screenshots`。
9. 复查搜索引擎后台。
    - Google Search Console 已验证；下一步是复查 sitemap 从“无法读取”变为成功或给出更具体错误。
    - Bing Webmaster Tools 当前需要 Microsoft 登录并获取/配置 `PEEK_BING_SITE_VERIFICATION`。
    - GitHub Pages workflow 已支持通过 `PEEK_BING_SITE_VERIFICATION` repository variable 注入 Bing verification meta，可用 `script/configure_landing_variables.sh` 设置。
10. Upload build to App Store Connect。
11. 回填真实 App Store URL 到 landing CTA：用 `PEEK_APP_STORE_URL=... ./script/configure_app_store_url.py --dry-run` 先验证，再去掉 `--dry-run` 写入。
12. Submit for Review。

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
