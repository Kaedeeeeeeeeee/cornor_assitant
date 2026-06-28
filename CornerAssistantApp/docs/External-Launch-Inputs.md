# Corner Peek External Launch Inputs

最后更新：2026-06-28 18:03 JST

这个文件只记录代码和本机 CLI 无法安全代办的外部账号、后台表单、真实联系方式和最终 URL。执行这些项目时，不要在聊天或日志里粘贴密码、验证码、恢复码、API private key 或完整付款/银行信息。

## Analytics

- [x] 决策：首发启用 landing GA4。
  - 当前建议：使用当前 Google Analytics 账号 `ZHANG SHIFENG` 中的属性 `とりあえずこの名前使う` 创建 Web data stream。
  - 当前浏览器状态：2026-06-28 05:45 JST 页面仍提示 `データ ストリームが見つかりませんでした`，未发现 `G-...` Measurement ID。
  - Web stream URL：`https://kaedeeeeeeeeee.github.io/cornor_assitant/`
  - Web stream name 建议：`Corner Peek Landing Page`
  - 需要输入/确认：允许创建 Web data stream，或直接提供已有 `G-...` Measurement ID。
  - 拿到 ID 后执行：

```bash
PEEK_GA_MEASUREMENT_ID=G-XXXXXXXXXX \
  ./script/configure_landing_variables.sh --rerun-pages --check-after
```

## Search Consoles

- [x] Google Search Console ownership verified.
- [ ] Google Search Console sitemap status.
  - 当前 sitemap 已提交。
  - 当前浏览器状态：2026-06-28 05:45 JST `/sitemap.xml` 行仍显示类型 `不明`、提交日期 `2026/06/28`、状态 `取得できませんでした`、发现页面数 `0`；详情页显示 `サイトマップを読み込めませんでした`。
  - 机器校验：默认 UA、Googlebot UA、Bingbot UA 均可 HTTP 200 抓取 sitemap，并解析到 3 个预期 URL。
  - 需要输入/确认：只需后续复查 Search Console 页面状态；不要重复使用匿名 sitemap ping 作为上线证据。
- [ ] Bing Webmaster Tools.
  - 当前浏览器状态：2026-06-28 05:45 JST 仍是未登录公开介绍页，显示 `Sign In` / `Get started`。
  - 需要输入/确认：用于 Bing Webmaster Tools 的 Microsoft 账号，或由用户登录后提供 `msvalidate.01` meta tag 的 `content` 值。
  - 拿到 token 后执行：

```bash
PEEK_BING_SITE_VERIFICATION=bing_token \
  ./script/configure_landing_variables.sh --rerun-pages --check-after
```

## Apple Developer And App Store Connect

- [x] Apple Developer Program account access.
  - 当前本机状态：`Apple Distribution` identity、`3rd Party Mac Developer Installer` certificate 和 `com.shifeng.peek` App Store profile 均可用于本机 App Store export。
  - 2026-06-28 18:00 JST 已将 `CornerAssistantApp/export_options_app_store.plist` 改为 manual signing，避免 CLI export 依赖 Xcode Accounts 登录态。
- [x] Apple Developer Program License Agreement.
  - 2026-06-28 13:00 JST 已在 Apple Developer 账号中接受最新 PLA；App Store Connect apps 列表不再显示协议更新横幅。
- [x] Apple Developer Bundle ID / App ID.
  - 2026-06-28 13:00 JST 已在 Certificates, Identifiers & Profiles 注册 `Corner Peek` / `com.shifeng.peek`，App ID Prefix 为 `Y4FV6WUU4V`。
- [ ] Paid Apps Agreement, tax, and banking.
  - 需要输入/确认：已签署 Paid Apps Agreement，并完成税务、银行和付费销售相关信息。
- [x] App Store Connect app record.
  - 2026-06-28 15:25 JST 已创建 `Corner Peek` macOS app record。
  - App Store Connect app id：`6785167787`。
  - App name：`Corner Peek`
  - Bundle ID：`com.shifeng.peek`
  - SKU：`corner-peek-macos-001`
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

- [x] `com.shifeng.peek` App Store provisioning profile.
  - 2026-06-28 17:49 JST 已创建并安装 `Corner Peek Mac App Store`，UUID `725ce297-837d-47df-b5ec-1593515efaac`。
  - Profile App ID：`Y4FV6WUU4V.com.shifeng.peek`；Platform：`OSX`；Expires：`2027/05/17`。
- [x] App Store distribution export.
  - 2026-06-28 18:00 JST 以下命令通过，导出并验证 `/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`：

```bash
PEEK_CHECK_EXPORT=1 ./script/check_external_readiness.py
```

- [ ] Upload build to App Store Connect.
  - 当前可上传文件：`/tmp/peek-appstore/external-readiness-export/Corner Peek.pkg`
  - 当前阻塞：本机已有 API key file `~/.appstoreconnect/private_keys/AuthKey_99STZKX674.p8`，但未找到 App Store Connect API issuer id；`altool` 上传仍需要 `--api-issuer`，或改用 Apple ID app-specific password / 已登录 Xcode Organizer / Transporter。
  - 拿到 issuer id 后可先运行：

```bash
xcrun altool --list-providers \
  --api-key 99STZKX674 \
  --api-issuer ISSUER_ID \
  --output-format json
```

  - 确认 provider 后再上传 build，并等待 processing 完成后选择 build 加入版本 `1.0`。

## Screenshots

- [x] Screen Recording permission.
  - 2026-06-28 15:45 JST `PEEK_CHECK_SCREENSHOT=1 PEEK_CHECK_QA_SMOKE=1 ./script/check_external_readiness.py` 已确认截图权限可用。
- [x] Generate App Store screenshots.

```bash
./script/capture_app_store_screenshot.sh
```

  - 已生成 `/tmp/peek-app-store-screenshots/01-hot-corner-panel-2880x1800.png` 至 `05-pinned-panel-2880x1800.png`，全部为 2880x1800。
  - 2026-06-28 15:45 JST 视觉快检通过：未发现黑图、个人信息、Xcode/终端痕迹或旧名。
  - 上传前仍需在 App Store Connect 中按最终页面预览做一次人工顺序审校。

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
