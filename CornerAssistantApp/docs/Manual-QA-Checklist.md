# Peek Manual QA Checklist

最后更新：2026-06-28 05:26 JST

这个清单用于 App Store 上传前的可见桌面/干净用户会话人工验收。自动化已经覆盖的项目保留在 `Launch-Plan.md` 和 `script/launch_verify.sh`；这里专门记录当前 Codex/shell 会话无法可靠证明的真实交互、截图和后台条件。

## 测试前准备

- [ ] 使用 macOS 15.0 或更高版本。
- [ ] 使用干净桌面，关闭无关窗口、通知、终端、Xcode、个人聊天和浏览器隐私内容。
- [ ] 使用 Release build、App Store exported app，或接近最终签名的候选 build。
- [ ] 如果要采集截图，给当前终端/Codex 宿主或截图工具授予 Screen Recording 权限。
- [ ] 准备记录证据：测试日期、macOS 版本、build 版本、截图目录、失败现象和复现步骤。

## 必跑交互

### 首次启动

- [ ] 启动 Peek。
- [ ] 菜单栏出现 Peek 图标。
- [ ] App 不弹出登录、注册、分析同意、网络权限或无关欢迎流程。
- [ ] 初始面板默认隐藏，不挡住桌面。
- 通过标准：用户可以不读说明直接从菜单栏或热角开始使用。

### 菜单栏图标点击

- [ ] 左键点击菜单栏 Peek 图标。
- [ ] 面板展开。
- [ ] 再次点击或点击外部区域后，未固定面板可收起。
- 通过标准：左键行为符合普通菜单栏工具预期，没有卡死、重复窗口或焦点异常。

### 菜单栏右键/control-click 菜单

- [ ] 右键或 control-click 菜单栏 Peek 图标。
- [ ] 菜单包含 Hot Corner、Launch at Login、Language、Quit。
- [ ] Hot Corner 子菜单包含 top-left、top-right、bottom-left、bottom-right 四项，并能切换当前选中项。
- [ ] Language 子菜单包含 English、简体中文、日本語，并能切换界面文案。
- [ ] Quit 可以退出 App。
- 通过标准：菜单结构、语言和热角设置与三语言 App Store 文案一致。

### 热角唤出和自动收起

- [ ] 分别设置四个热角并把鼠标移动到对应屏幕角落。
- [ ] 面板从正确边缘出现，尺寸和位置正常。
- [ ] 未固定时，点击外部或移出交互区后面板收起。
- [ ] 固定时，点击外部不会自动收起。
- 通过标准：四个热角都可用，固定/未固定状态清楚，不误触发大面积遮挡。

### 面板尺寸调整

- [ ] 拖拽面板边缘调整宽度。
- [ ] 拖拽面板边缘调整高度。
- [ ] 关闭并重新打开面板，确认尺寸保存且不会超过可见屏幕。
- 通过标准：拖拽顺滑，最小/最大尺寸合理，重开后布局没有跳动或越界。

### 搜索、URL 和标签页

- [ ] 输入普通关键词并回车，打开 Google 搜索结果。
- [ ] 输入完整 HTTPS URL 并回车，直接打开该网页。
- [ ] 输入裸域名和带路径 URL，确认按网页打开而不是错误搜索。
- [ ] 新建、切换、关闭普通标签页。
- [ ] 关闭最后一个普通标签页后仍有可继续使用的起始页或替代标签。
- 通过标准：搜索和 URL 判断符合预期，标签页不会丢失可用入口。

### 固定网站

- [ ] 打开一个网站并固定到侧栏。
- [ ] 从固定栏重新打开该网站。
- [ ] 移除固定网站。
- [ ] 尝试重复固定同一 URL，确认不会产生重复项。
- 通过标准：固定站点保存在本地，打开/移除/重复防护行为清楚。

### Launch at Login

- [ ] 在菜单栏菜单中开启 Launch at Login。
- [ ] 打开 macOS Login Items 设置，确认 Peek 状态符合预期。
- [ ] 退出并重新登录当前测试用户，确认 Peek 自动启动。
- [ ] 关闭 Launch at Login，并确认系统设置同步移除或禁用。
- 通过标准：系统登录项状态和 Peek 菜单状态一致，不需要额外 helper App 提示。

### WebKit 常见登录页面

- [ ] 打开 Google account 页面。
- [ ] 打开 Slack workspace 登录页。
- [ ] 打开 Notion 或另一个典型工作站点登录页。
- [ ] 验证弹窗、重定向、返回/前进和输入框焦点正常。
- 通过标准：Peek 不需要处理用户凭据，但 WebKit 登录流程不能因为 user agent、popup 或 navigation delegate 明显卡住。

### 无网络环境

- [ ] 断开网络或使用系统网络设置进入无网络状态。
- [ ] 启动 Peek。
- [ ] 输入关键词和 URL。
- [ ] 打开已有固定网站。
- [ ] 恢复网络后重新搜索/打开页面。
- 通过标准：无网络时 App 不崩溃、不保留误导性的旧搜索建议，恢复网络后可继续使用。

## App Store 截图验收

- [ ] 运行 `./script/capture_app_store_screenshot.sh`，或用等价的真实可见桌面流程采集截图。
- [ ] 至少准备 5 张 16:10 截图，建议 2880x1800 或 2560x1600。
- [ ] 截图覆盖：热角面板、搜索/URL 输入、多标签、固定网站、固定面板。
- [ ] 截图不包含终端、Xcode、调试日志、个人账号、未发布功能或隐私信息。
- [ ] 截图中不宣传 Bing、搜索引擎选择、selected-text search、macOS 14 或 Sonoma 兼容。

## 上架前人工证据

- [ ] 记录测试日期和 tester。
- [ ] 记录 macOS 版本。
- [ ] 记录 Peek build 版本：`1.0 (1)`。
- [ ] 记录使用的 build 来源：Release archive、App Store export 或 Xcode Archive/Organizer。
- [ ] 记录截图目录。
- [ ] 记录任何失败项和是否阻塞 App Store 提交。

## 当前已知人工阻塞

- [ ] App Store Connect/Apple Developer 登录、协议、税务、银行和 App record。
- [ ] `com.shifeng.peek` App Store provisioning profile。
- [ ] App Store distribution export 和上传。
- [ ] App Store 截图素材。
- [ ] App Review 真实联系电话。
- [ ] GA4 Measurement ID 或明确首发暂不开启 landing analytics。
- [ ] Bing Webmaster Tools 登录和站点提交。
- [ ] Google Search Console sitemap 处理状态复查。
