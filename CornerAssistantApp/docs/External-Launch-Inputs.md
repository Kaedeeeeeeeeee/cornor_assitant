# Peek External Launch Inputs

最后更新：2026-06-28 05:31 JST

这个文件只记录代码和本机 CLI 无法安全代办的外部账号、后台表单、真实联系方式和最终 URL。执行这些项目时，不要在聊天或日志里粘贴密码、验证码、恢复码、API private key 或完整付款/银行信息。

## Analytics

- [ ] 决策：首发是否启用 landing GA4。
  - 当前建议：如果要启用，使用当前 Google Analytics 账号 `ZHANG SHIFENG` 中的属性 `とりあえずこの名前使う` 创建 Web data stream。
  - Web stream URL：`https://kaedeeeeeeeeee.github.io/cornor_assitant/`
  - Web stream name 建议：`Peek Landing Page`
  - 需要输入/确认：允许创建 Web data stream，或直接提供已有 `G-...` Measurement ID，或明确首发暂不开启 analytics。
  - 拿到 ID 后执行：

```bash
PEEK_GA_MEASUREMENT_ID=G-XXXXXXXXXX \
  ./script/configure_landing_variables.sh --rerun-pages --check-after
```

## Search Consoles

- [x] Google Search Console ownership verified.
- [ ] Google Search Console sitemap status.
  - 当前 sitemap 已提交。
  - 机器校验：默认 UA、Googlebot UA、Bingbot UA 均可 HTTP 200 抓取 sitemap，并解析到 3 个预期 URL。
  - 需要输入/确认：只需后续复查 Search Console 页面状态；不要重复使用匿名 sitemap ping 作为上线证据。
- [ ] Bing Webmaster Tools.
  - 需要输入/确认：用于 Bing Webmaster Tools 的 Microsoft 账号，或由用户登录后提供 `msvalidate.01` meta tag 的 `content` 值。
  - 拿到 token 后执行：

```bash
PEEK_BING_SITE_VERIFICATION=bing_token \
  ./script/configure_landing_variables.sh --rerun-pages --check-after
```

## Apple Developer And App Store Connect

- [ ] Apple Developer Program account access.
  - 需要输入/确认：登录 Xcode Settings > Accounts 的 Apple Developer 账号，并确保 Team ID 为 `Y4FV6WUU4V` 或更新 `CornerAssistantApp/export_options_app_store.plist`。
- [ ] Apple Developer Program License Agreement.
  - 需要输入/确认：账号持有人在 Apple Developer/App Store Connect 接受最新 PLA。
- [ ] Paid Apps Agreement, tax, and banking.
  - 需要输入/确认：已签署 Paid Apps Agreement，并完成税务、银行和付费销售相关信息。
- [ ] App Store Connect app record.
  - App name：`Peek`
  - Bundle ID：`com.shifeng.peek`
  - SKU 建议：`peek-macos-001`
  - Primary language：English (U.S.)
  - Category：Productivity
  - Price：US$5.99，一次买断
  - Release option：Manual release
- [ ] DSA / trader status and availability.
  - 当前默认建议：All Countries or Regions，除非税务、银行、DSA 或地区合规要求排除。
  - 需要输入/确认：如果包含 EU 地区，完成 DSA trader status 和可公开联系信息；如果不覆盖 EU，调整 availability。
- [ ] Real App Review contact phone.
  - 需要输入/确认：App Review 可联系的真实电话。不要提交占位符。
- [ ] App Review notes.
  - 已准备：`/tmp/peek-app-store-metadata/app_review_notes.txt`
  - 需要输入/确认：在 App Store Connect 粘贴后确认内容未被后台格式化破坏。

## Provisioning, Export, And Upload

- [ ] `com.shifeng.peek` App Store provisioning profile.
  - 当前 CLI 阻塞：`No Accounts / no com.shifeng.peek App Store profile`
  - 需要输入/确认：Xcode 已登录可用 Apple Developer 账号，并创建或刷新 App Store profile。
- [ ] App Store distribution export.
  - 账号/profile 准备好后执行：

```bash
PEEK_CHECK_EXPORT=1 PEEK_ALLOW_PROVISIONING_UPDATES=1 ./script/check_external_readiness.py
```

- [ ] Upload build to App Store Connect.
  - 推荐方式：Xcode Organizer。
  - 上传后需要确认 build processing 完成，并选择 build 加入版本 `1.0`。

## Screenshots

- [ ] Screen Recording permission.
  - 当前 CLI 阻塞：`Screen Recording/window capture permission is not usable`
  - 需要输入/确认：在可见干净桌面中授予当前终端/Codex 宿主或截图工具 Screen Recording 权限。
- [ ] Generate App Store screenshots.

```bash
./script/capture_app_store_screenshot.sh
```

  - 成功时应生成 `/tmp/peek-app-store-screenshots/01-hot-corner-panel-2880x1800.png` 至 `05-pinned-panel-2880x1800.png`。
  - 上传前同时按 `CornerAssistantApp/docs/Manual-QA-Checklist.md` 做截图内容审校。

## Final Store URL

- [ ] True Mac App Store URL.
  - App Store 页面可访问后，先 dry-run：

```bash
PEEK_APP_STORE_URL=https://apps.apple.com/.../app/.../id... \
  ./script/configure_app_store_url.py --dry-run
```

  - 确认后正式写入：

```bash
PEEK_APP_STORE_URL=https://apps.apple.com/.../app/.../id... \
  ./script/configure_app_store_url.py
```

  - 写入后 rerun Pages workflow 并复查 landing CTA。
