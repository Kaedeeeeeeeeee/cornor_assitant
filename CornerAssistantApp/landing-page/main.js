const SITE_BASE_URL = "https://kaedeeeeeeeeee.github.io/cornor_assitant/";
const GA_MEASUREMENT_ID =
    window.PEEK_GA_MEASUREMENT_ID ||
    document.documentElement.getAttribute("data-ga-measurement-id") ||
    "";

const translations = {
    zh: {
        label: "中",
        htmlLang: "zh-CN",
        meta: {
            home: {
                title: "Peek - macOS 屏幕边缘的轻量浏览器",
                description: "Peek 是一款 macOS 菜单栏轻量浏览器。把鼠标移到热角，即可滑出面板，搜索、打开网页和访问常用网站。",
                ogTitle: "Peek - macOS 屏幕边缘的轻量浏览器",
                ogDescription: "把鼠标移到热角，快速打开搜索、网页和常用站点，用完即收起。",
                twitterTitle: "Peek - macOS 屏幕边缘的轻量浏览器",
                twitterDescription: "把鼠标移到热角，快速打开搜索、网页和常用站点，用完即收起。"
            },
            privacy: {
                title: "Peek 隐私政策",
                description: "了解 Peek macOS 应用如何处理本地数据、网页访问、搜索请求和官网分析。",
                ogTitle: "Peek 隐私政策",
                ogDescription: "Peek 不需要账号，应用偏好和固定站点保存在你的 Mac 本地。",
                twitterTitle: "Peek 隐私政策",
                twitterDescription: "Peek 不需要账号，应用偏好和固定站点保存在你的 Mac 本地。"
            },
            support: {
                title: "Peek 技术支持",
                description: "Peek macOS 应用的常见问题、使用方式、系统要求和支持邮箱。",
                ogTitle: "Peek 技术支持",
                ogDescription: "查看 Peek 的热角唤出、搜索、标签页、固定站点和支持联系方式。",
                twitterTitle: "Peek 技术支持",
                twitterDescription: "查看 Peek 的热角唤出、搜索、标签页、固定站点和支持联系方式。"
            }
        },
        text: {
            navHome: "首页",
            navHow: "玩法",
            navFeatures: "功能",
            navPrivacy: "隐私",
            navSupport: "技术支持",
            fSupport: "技术支持",
            eyebrow: "macOS 菜单栏工具",
            heroTitle: "隐于无形，触手可及。",
            heroSub: "把鼠标移到热角，Peek 即刻从屏幕边缘滑出。搜索、打开网页、直达常用网站，用完即收起。",
            ctaTop: "即将登陆",
            heroSecondary: "看看怎么用",
            req: "需要 macOS 15.0 或更高版本",
            scFile: "文件",
            scEdit: "编辑",
            scView: "显示",
            scQuery: "swiftui 动画",
            scSug1: "swiftui 动画 教程",
            scSug2: "withAnimation 用法",
            scSug3: "matchedGeometryEffect",
            howTitle: "一个手势，三步完成",
            step1t: "移到边缘",
            step1d: "把鼠标推到你设置的热角，不需要快捷键，也不需要先点击。",
            step2t: "唤出面板",
            step2d: "Peek 从边缘滑出，搜索框自动聚焦，可以直接输入关键词或网址。",
            step3t: "用完即走",
            step3d: "完成浏览或搜索后，面板自动收起，桌面重新回到清爽状态。",
            featTitle: "为专注而生的小工具",
            f1t: "边缘滑出面板",
            f1d: "从菜单栏安静待命，到屏幕边缘快速出现，适合临时搜索和短时间浏览。",
            f2t: "快捷搜索",
            f2d: "在面板里输入关键词或网址，快速搜索或直接打开网页。",
            f3t: "多标签浏览",
            f3d: "内置轻量 WebKit 浏览器，支持多标签页管理，不必切换到完整浏览器窗口。",
            f4t: "常用网站",
            f4d: "固定每天会打开的网站，一键回到 AI 工具、文档、团队沟通和工作页面。",
            privTitle: "你的数据，只属于你",
            privSub: "Peek 不需要账号，应用偏好和固定站点保存在你的 Mac 本地。网页访问和搜索请求直接发往对应网站或默认搜索服务。",
            priv1: "上传到我们的服务器",
            priv2: "App 内分析埋点",
            priv3: "账号登录",
            finalTitle: "把 Peek 放进菜单栏",
            finalSub: "安静地待命，需要时一推即到。即将登陆 Mac App Store。",
            privacyHeroTitle: "隐私政策",
            privacyHeroSub: "Peek 的原则很简单：应用里的个人使用数据留在你的 Mac 上。官网分析与 App 本身分开处理。",
            lastUpdated: "最后更新：2026 年 6 月 27 日",
            policy1Title: "1. 应用内信息收集",
            policy1Body: "Peek 不要求账号登录，也不会把你的姓名、邮箱、位置、浏览记录或使用行为发送到开发者服务器。",
            policy2Title: "2. 本地数据存储",
            policy2Body: "语言、热角、窗口尺寸、固定网站和其他偏好设置只保存在你的 Mac 本地。删除应用或清理对应本地数据后，这些设置会随之移除。",
            policy3Title: "3. 网页访问与搜索",
            policy3Body: "Peek 内置 WebKit 浏览器。你打开网页时，请求直接发送给对应网站；你输入关键词或查看搜索建议时，请求会发送给默认搜索服务。Peek 不会拦截、记录或分析这些浏览内容。",
            policy4Title: "4. 麦克风权限",
            policy4Body: "Peek 本身不会录音。你在内置浏览器中打开的网站可能会请求麦克风权限，用于网页通话、语音输入等功能。授权由 macOS 和对应网站处理，你可以在系统设置中撤销权限。",
            policy5Title: "5. 官网分析",
            policy5Body: "Peek 官网可能使用 Google Analytics 等分析工具了解页面访问、来源和按钮点击。该分析只用于官网，不嵌入 macOS 应用。你可以通过浏览器设置、内容拦截器或隐私插件限制这类分析。",
            policy6Title: "6. 第三方网站",
            policy6Body: "你在 Peek 内访问的网站由对应第三方运营，它们可能有自己的 Cookie、登录状态、分析工具和隐私政策。",
            policy7Title: "7. 联系方式",
            policy7Body: "如果你对隐私政策有问题，请发送邮件至 f.shera.09@gmail.com。",
            supportHeroTitle: "技术支持",
            supportHeroSub: "这里整理了 Peek 首发版本最常见的使用问题。需要人工支持时，可以直接发邮件。",
            q1Title: "如何唤出 Peek 面板？",
            q1Body: "把鼠标移到你设置的热角，Peek 会从屏幕边缘滑出。默认热角可以在应用设置里调整。",
            q2Title: "如何隐藏或固定面板？",
            q2Body: "完成操作后移开鼠标，面板会自动收起。需要临时停留时，可以使用面板里的固定按钮。",
            q3Title: "如何搜索或打开网址？",
            q3Body: "在面板搜索框输入关键词并按回车即可搜索；输入完整网址时，Peek 会直接打开对应网页。",
            q4Title: "如何管理常用网站？",
            q4Body: "打开网页后使用固定操作加入常用网站列表。你可以从侧栏快速打开，也可以移除不再需要的网站。",
            q5Title: "Peek 支持多标签吗？",
            q5Body: "支持。你可以新建、关闭和切换标签页，用轻量面板完成临时浏览任务。",
            q6Title: "应用需要什么系统版本？",
            q6Body: "Peek 需要 macOS 15.0 或更高版本。",
            q7Title: "如何联系支持？",
            q7Body: "请发送邮件到 f.shera.09@gmail.com，并尽量附上 macOS 版本、Peek 版本、问题步骤和截图。",
            contactText: "需要人工支持或想反馈功能建议？",
            contactButton: "发送邮件"
        }
    },
    en: {
        label: "EN",
        htmlLang: "en",
        meta: {
            home: {
                title: "Peek - A Lightweight Browser from the macOS Screen Edge",
                description: "Peek is a lightweight macOS menu bar browser. Move your cursor to a hot corner to slide out search, web pages, and pinned sites.",
                ogTitle: "Peek - A Lightweight Browser from the macOS Screen Edge",
                ogDescription: "Move your cursor to a hot corner, open search or a site, then tuck the panel away.",
                twitterTitle: "Peek - A Lightweight Browser from the macOS Screen Edge",
                twitterDescription: "Move your cursor to a hot corner, open search or a site, then tuck the panel away."
            },
            privacy: {
                title: "Peek Privacy Policy",
                description: "Learn how Peek for macOS handles local data, web browsing, search requests, and website analytics.",
                ogTitle: "Peek Privacy Policy",
                ogDescription: "Peek does not require an account. Preferences and pinned sites stay on your Mac.",
                twitterTitle: "Peek Privacy Policy",
                twitterDescription: "Peek does not require an account. Preferences and pinned sites stay on your Mac."
            },
            support: {
                title: "Peek Support",
                description: "Common questions, system requirements, and support contact for Peek for macOS.",
                ogTitle: "Peek Support",
                ogDescription: "Get help with hot corners, search, tabs, pinned sites, and support contact details.",
                twitterTitle: "Peek Support",
                twitterDescription: "Get help with hot corners, search, tabs, pinned sites, and support contact details."
            }
        },
        text: {
            navHome: "Home",
            navHow: "How it works",
            navFeatures: "Features",
            navPrivacy: "Privacy",
            navSupport: "Support",
            fSupport: "Support",
            eyebrow: "macOS menu bar utility",
            heroTitle: "Out of sight. Right when you need it.",
            heroSub: "Move your cursor to a hot corner and Peek slides out from the screen edge. Search, open pages, and jump to pinned sites, then tuck it away.",
            ctaTop: "Coming soon to",
            heroSecondary: "See how it works",
            req: "Requires macOS 15.0 or later",
            scFile: "File",
            scEdit: "Edit",
            scView: "View",
            scQuery: "swiftui animation",
            scSug1: "swiftui animation tutorial",
            scSug2: "withAnimation examples",
            scSug3: "matchedGeometryEffect",
            howTitle: "One gesture, three steps",
            step1t: "Move to the edge",
            step1d: "Push your cursor into the hot corner you chose. No keyboard shortcut or first click required.",
            step2t: "Reveal the panel",
            step2d: "Peek slides out and focuses the search field so you can type a query or URL immediately.",
            step3t: "Get back to work",
            step3d: "After a quick search or browse, the panel tucks away and your desktop stays clear.",
            featTitle: "A small tool built for focus",
            f1t: "Edge-triggered panel",
            f1d: "Quiet in the menu bar, quick from the screen edge when you need a temporary search or browser.",
            f2t: "Quick search",
            f2d: "Type a keyword or URL in the panel to search or open a page directly.",
            f3t: "Tabbed browsing",
            f3d: "A lightweight WebKit browser with tabs, so you do not need to switch to a full browser window.",
            f4t: "Pinned sites",
            f4d: "Pin the sites you open every day and jump back to AI tools, docs, team chat, and work pages.",
            privTitle: "Your data stays yours",
            privSub: "Peek does not require an account. App preferences and pinned sites stay on your Mac. Web and search requests go directly to the website or default search service.",
            priv1: "uploaded to our servers",
            priv2: "in-app analytics",
            priv3: "account login",
            finalTitle: "Put Peek in your menu bar",
            finalSub: "Quiet until needed, one push away. Coming soon to the Mac App Store.",
            privacyHeroTitle: "Privacy Policy",
            privacyHeroSub: "Peek's rule is simple: personal app data stays on your Mac. Website analytics are handled separately from the app.",
            lastUpdated: "Last updated: June 27, 2026",
            policy1Title: "1. In-app information collection",
            policy1Body: "Peek does not require an account and does not send your name, email, location, browsing history, or usage behavior to developer-operated servers.",
            policy2Title: "2. Local data storage",
            policy2Body: "Language, hot corner, window size, pinned sites, and other preferences are stored locally on your Mac. Removing the app or clearing the related local data removes those settings.",
            policy3Title: "3. Web browsing and search",
            policy3Body: "Peek includes a WebKit browser. Web requests go directly to the sites you visit. Keyword searches and suggestions go to the default search service. Peek does not intercept, log, or analyze browsing content.",
            policy4Title: "4. Microphone permission",
            policy4Body: "Peek itself does not record audio. Websites opened inside the built-in browser may request microphone access for features such as calls or voice input. Permission is handled by macOS and the website, and you can revoke it in System Settings.",
            policy5Title: "5. Website analytics",
            policy5Body: "The Peek website may use analytics tools such as Google Analytics to understand page views, referrers, and button clicks. This applies to the public website only and is not embedded in the macOS app. You can limit analytics through browser settings, content blockers, or privacy extensions.",
            policy6Title: "6. Third-party websites",
            policy6Body: "Websites you visit inside Peek are operated by third parties and may use their own cookies, login states, analytics tools, and privacy policies.",
            policy7Title: "7. Contact",
            policy7Body: "Questions about this policy can be sent to f.shera.09@gmail.com.",
            supportHeroTitle: "Support",
            supportHeroSub: "Common questions for the first release of Peek. For direct help, email support.",
            q1Title: "How do I reveal the Peek panel?",
            q1Body: "Move your cursor to the hot corner you configured and Peek slides out from the screen edge. The default hot corner can be changed in app settings.",
            q2Title: "How do I hide or pin the panel?",
            q2Body: "Move away when you are done and the panel will tuck itself away. Use the pin control when you need it to stay visible temporarily.",
            q3Title: "How do I search or open a URL?",
            q3Body: "Type a keyword and press Return to search. Type a full URL to open that page directly.",
            q4Title: "How do I manage pinned sites?",
            q4Body: "Open a page and use the pin action to add it to your pinned sites. You can launch it from the sidebar or remove it later.",
            q5Title: "Does Peek support tabs?",
            q5Body: "Yes. You can create, close, and switch tabs for lightweight browsing tasks.",
            q6Title: "What system version does Peek require?",
            q6Body: "Peek requires macOS 15.0 or later.",
            q7Title: "How do I contact support?",
            q7Body: "Email f.shera.09@gmail.com with your macOS version, Peek version, reproduction steps, and screenshots if possible.",
            contactText: "Need help or want to suggest a feature?",
            contactButton: "Email support"
        }
    },
    ja: {
        label: "日",
        htmlLang: "ja",
        meta: {
            home: {
                title: "Peek - macOS の画面端から使える軽量ブラウザ",
                description: "Peek は macOS のメニューバーに常駐する軽量ブラウザです。ホットコーナーにカーソルを移動すると、検索、Web ページ、固定サイトをすばやく開けます。",
                ogTitle: "Peek - macOS の画面端から使える軽量ブラウザ",
                ogDescription: "ホットコーナーから検索やサイトをすばやく開き、使い終わったらしまえます。",
                twitterTitle: "Peek - macOS の画面端から使える軽量ブラウザ",
                twitterDescription: "ホットコーナーから検索やサイトをすばやく開き、使い終わったらしまえます。"
            },
            privacy: {
                title: "Peek プライバシーポリシー",
                description: "Peek for macOS のローカルデータ、Web アクセス、検索リクエスト、Web サイト分析の扱いについて説明します。",
                ogTitle: "Peek プライバシーポリシー",
                ogDescription: "Peek はアカウント不要で、設定と固定サイトは Mac に保存されます。",
                twitterTitle: "Peek プライバシーポリシー",
                twitterDescription: "Peek はアカウント不要で、設定と固定サイトは Mac に保存されます。"
            },
            support: {
                title: "Peek サポート",
                description: "Peek for macOS のよくある質問、動作環境、サポート連絡先です。",
                ogTitle: "Peek サポート",
                ogDescription: "ホットコーナー、検索、タブ、固定サイト、サポート連絡先を確認できます。",
                twitterTitle: "Peek サポート",
                twitterDescription: "ホットコーナー、検索、タブ、固定サイト、サポート連絡先を確認できます。"
            }
        },
        text: {
            navHome: "ホーム",
            navHow: "使い方",
            navFeatures: "機能",
            navPrivacy: "プライバシー",
            navSupport: "サポート",
            fSupport: "サポート",
            eyebrow: "macOS メニューバーユーティリティ",
            heroTitle: "ふだんは静かに。必要な時だけすぐに。",
            heroSub: "ホットコーナーにカーソルを移動すると、Peek が画面端から表示されます。検索、Web ページ、固定サイトをすばやく開き、使い終わったらしまえます。",
            ctaTop: "近日公開",
            heroSecondary: "使い方を見る",
            req: "macOS 15.0 以降が必要です",
            scFile: "ファイル",
            scEdit: "編集",
            scView: "表示",
            scQuery: "swiftui animation",
            scSug1: "swiftui animation tutorial",
            scSug2: "withAnimation examples",
            scSug3: "matchedGeometryEffect",
            howTitle: "ひとつの操作で、すぐ使える",
            step1t: "画面端へ移動",
            step1d: "設定したホットコーナーにカーソルを移動します。ショートカットや事前クリックは不要です。",
            step2t: "パネルを表示",
            step2d: "Peek が画面端から表示され、検索欄にすぐ入力できます。",
            step3t: "作業に戻る",
            step3d: "検索や短いブラウズが終わると、パネルはしまわれ、デスクトップはすっきりしたままです。",
            featTitle: "集中のための小さなツール",
            f1t: "エッジパネル",
            f1d: "普段はメニューバーに待機し、必要な時だけ画面端からすばやく表示されます。",
            f2t: "クイック検索",
            f2d: "パネルにキーワードや URL を入力して、検索またはページを直接開けます。",
            f3t: "タブブラウズ",
            f3d: "WebKit ベースの軽量ブラウザで、フルサイズのブラウザに切り替えずにタブを使えます。",
            f4t: "固定サイト",
            f4d: "毎日使う AI ツール、ドキュメント、チームチャット、作業ページをすばやく開けます。",
            privTitle: "データはあなたのもの",
            privSub: "Peek はアカウント不要です。アプリ設定と固定サイトは Mac に保存され、Web と検索リクエストは対象サイトまたは既定の検索サービスへ直接送信されます。",
            priv1: "開発者サーバーへのアップロード",
            priv2: "アプリ内分析",
            priv3: "アカウントログイン",
            finalTitle: "Peek をメニューバーに",
            finalSub: "必要な時だけ、画面端からすぐに。Mac App Store で近日公開予定です。",
            privacyHeroTitle: "プライバシーポリシー",
            privacyHeroSub: "Peek の方針はシンプルです。アプリ内の個人利用データは Mac に保存され、Web サイト分析はアプリとは別に扱われます。",
            lastUpdated: "最終更新日：2026年6月27日",
            policy1Title: "1. アプリ内の情報収集",
            policy1Body: "Peek はアカウントを必要とせず、名前、メール、位置情報、閲覧履歴、利用行動を開発者のサーバーへ送信しません。",
            policy2Title: "2. ローカルデータ保存",
            policy2Body: "言語、ホットコーナー、ウィンドウサイズ、固定サイト、その他の設定は Mac にローカル保存されます。アプリを削除するか関連するローカルデータを消去すると、これらの設定も削除されます。",
            policy3Title: "3. Web アクセスと検索",
            policy3Body: "Peek には WebKit ブラウザが含まれます。Web リクエストは訪問先サイトへ直接送信されます。キーワード検索や候補表示は既定の検索サービスへ送信されます。Peek は閲覧内容を傍受、記録、分析しません。",
            policy4Title: "4. マイク権限",
            policy4Body: "Peek 自体は音声を録音しません。内蔵ブラウザで開いた Web サイトが、通話や音声入力などのためにマイク権限を求める場合があります。権限は macOS と対象サイトが処理し、システム設定で取り消すことができます。",
            policy5Title: "5. Web サイト分析",
            policy5Body: "Peek の Web サイトでは、ページ閲覧、参照元、ボタンクリックを把握するために Google Analytics などの分析ツールを使用する場合があります。これは公開 Web サイトのみを対象とし、macOS アプリには組み込まれません。ブラウザ設定、コンテンツブロッカー、プライバシー拡張で制限できます。",
            policy6Title: "6. 第三者の Web サイト",
            policy6Body: "Peek 内で訪問する Web サイトは第三者が運営しており、独自の Cookie、ログイン状態、分析ツール、プライバシーポリシーを持つ場合があります。",
            policy7Title: "7. 連絡先",
            policy7Body: "このポリシーに関する質問は f.shera.09@gmail.com までお送りください。",
            supportHeroTitle: "サポート",
            supportHeroSub: "Peek 初回リリースでよくある質問です。直接のサポートが必要な場合はメールでご連絡ください。",
            q1Title: "Peek パネルを表示するには？",
            q1Body: "設定したホットコーナーにカーソルを移動すると、Peek が画面端から表示されます。既定のホットコーナーはアプリ設定で変更できます。",
            q2Title: "パネルを隠す、または固定するには？",
            q2Body: "操作が終わったらカーソルを離すと、パネルは自動的にしまわれます。一時的に表示したままにしたい場合は固定ボタンを使います。",
            q3Title: "検索や URL を開くには？",
            q3Body: "キーワードを入力して Return を押すと検索できます。完全な URL を入力すると、そのページを直接開きます。",
            q4Title: "固定サイトを管理するには？",
            q4Body: "ページを開いた状態で固定操作を使うと、固定サイトに追加できます。サイドバーから開いたり、不要になったサイトを削除したりできます。",
            q5Title: "Peek はタブに対応していますか？",
            q5Body: "はい。軽いブラウズ作業向けに、タブの作成、終了、切り替えができます。",
            q6Title: "必要な macOS バージョンは？",
            q6Body: "Peek には macOS 15.0 以降が必要です。",
            q7Title: "サポートに連絡するには？",
            q7Body: "macOS バージョン、Peek バージョン、再現手順、可能であればスクリーンショットを添えて f.shera.09@gmail.com までメールしてください。",
            contactText: "サポートや機能提案が必要ですか？",
            contactButton: "メールを送る"
        }
    }
};

document.addEventListener("DOMContentLoaded", () => {
    const initialLanguage = getInitialLanguage();
    setupLanguageSwitcher(initialLanguage);
    setLanguage(initialLanguage, false);
    setupAnalytics();
    setupTrackedLinks();
});

function getInitialLanguage() {
    const saved = localStorage.getItem("peek_lang");
    if (saved && translations[saved]) {
        return saved;
    }

    const browserLanguage = navigator.language.toLowerCase();
    if (browserLanguage.startsWith("ja")) return "ja";
    if (browserLanguage.startsWith("en")) return "en";
    return "zh";
}

function setupLanguageSwitcher(currentLanguage) {
    document.querySelectorAll("[data-lang]").forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.lang === currentLanguage));
        button.addEventListener("click", (event) => {
            event.preventDefault();
            setLanguage(button.dataset.lang, true);
        });
    });
}

function setLanguage(language, shouldTrack) {
    const selected = translations[language] ? language : "zh";
    const page = document.body.dataset.page || "home";
    const locale = translations[selected];

    localStorage.setItem("peek_lang", selected);
    document.documentElement.lang = locale.htmlLang;

    document.querySelectorAll("[data-lang]").forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.lang === selected));
    });

    document.querySelectorAll("[data-i18n]").forEach((element) => {
        const key = element.getAttribute("data-i18n");
        const value = locale.text[key];
        if (value) element.textContent = value;
    });

    const pageMeta = locale.meta[page] || locale.meta.home;
    document.querySelectorAll("[data-i18n-meta]").forEach((element) => {
        const key = element.getAttribute("data-i18n-meta");
        const value = pageMeta[key];
        if (!value) return;
        if (element.tagName === "TITLE") {
            document.title = value;
        } else {
            element.setAttribute("content", value);
        }
    });

    if (shouldTrack) {
        trackEvent("language_change", {
            language: selected,
            page
        });
    }
}

function setupAnalytics() {
    if (!/^G-[A-Z0-9]+$/.test(GA_MEASUREMENT_ID)) {
        window.peekAnalyticsEnabled = false;
        return;
    }

    window.peekAnalyticsEnabled = true;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function gtag() {
        window.dataLayer.push(arguments);
    };

    const script = document.createElement("script");
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(GA_MEASUREMENT_ID)}`;
    document.head.appendChild(script);

    window.gtag("js", new Date());
    window.gtag("config", GA_MEASUREMENT_ID, {
        page_title: document.title,
        page_location: window.location.href
    });
}

function setupTrackedLinks() {
    document.querySelectorAll("[data-analytics-event]").forEach((element) => {
        element.addEventListener("click", (event) => {
            if (element.classList.contains("is-disabled")) {
                event.preventDefault();
            }

            trackEvent(element.dataset.analyticsEvent, {
                page: document.body.dataset.page || "home",
                href: element.getAttribute("href") || ""
            });
        });
    });
}

function trackEvent(name, params = {}) {
    if (!window.peekAnalyticsEnabled || typeof window.gtag !== "function") {
        return;
    }

    window.gtag("event", name, params);
}

window.PeekLanding = {
    siteBaseUrl: SITE_BASE_URL,
    analyticsEnabled: () => Boolean(window.peekAnalyticsEnabled),
    setLanguage
};
