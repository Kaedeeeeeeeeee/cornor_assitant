const translations = {
    "zh": {
        "page_title": "Peek - macOS屏幕边缘的快捷助手",
        "nav_home": "首页",
        "nav_privacy": "隐私政策",
        "nav_support": "技术支持",
        "hero_subtitle": "macOS屏幕边缘的快捷助手",
        "hero_description": "隐于无形，触手可及。",
        "btn_download": "App Store 下载",
        "features_title": "核心功能",
        "feature_1_title": "边缘滑出面板",
        "feature_1_desc": "鼠标移至屏幕边缘，快速唤出工具面板，即用即走。",
        "feature_2_title": "多标签浏览",
        "feature_2_desc": "内置轻量浏览器，支持多标签页管理，浏览更高效。",
        "feature_3_title": "常用网站",
        "feature_3_desc": "固定你最常访问的网站，一键直达，无需重复输入。",
        "contact_text": "如果您遇到任何问题或有功能建议，请联系我们：",
        "contact_btn": "联系支持"
    },
    "en": {
        "page_title": "Peek - Quick Access from Screen Edge",
        "nav_home": "Home",
        "nav_privacy": "Privacy Policy",
        "nav_support": "Support",
        "hero_subtitle": "Quick Access from macOS Screen Edge",
        "hero_description": "Invisible until you need it.",
        "btn_download": "Download on the App Store",
        "features_title": "Key Features",
        "feature_1_title": "Edge Panel",
        "feature_1_desc": "Move cursor to screen edge to reveal the tool panel instantly.",
        "feature_2_title": "Tabbed Browsing",
        "feature_2_desc": "Built-in lightweight browser with multi-tab support.",
        "feature_3_title": "Pinned Sites",
        "feature_3_desc": "Pin your favorite websites for one-click access.",
        "contact_text": "If you encounter any issues or have feature suggestions, please reach out:",
        "contact_btn": "Contact Support"
    },
    "ja": {
        "page_title": "Peek - 画面端からクイックアクセス",
        "nav_home": "ホーム",
        "nav_privacy": "プライバシー",
        "nav_support": "サポート",
        "hero_subtitle": "macOS画面端からクイックアクセス",
        "hero_description": "必要なときだけ、そこに。",
        "btn_download": "App Storeからダウンロード",
        "features_title": "主な機能",
        "feature_1_title": "エッジパネル",
        "feature_1_desc": "カーソルを画面端に移動するだけでツールパネルが表示されます。",
        "feature_2_title": "タブブラウジング",
        "feature_2_desc": "マルチタブ対応の軽量ブラウザを内蔵。",
        "feature_3_title": "ピン留めサイト",
        "feature_3_desc": "よく使うサイトをワンクリックでアクセス。",
        "contact_text": "問題が発生した場合や機能の提案がある場合は、お問い合わせください：",
        "contact_btn": "サポートに連絡"
    }
};

document.addEventListener('DOMContentLoaded', () => {
    // Check saved language or browser language
    let currentLang = localStorage.getItem('peek_lang') || 'zh';
    
    // Normalize browser language
    if (!localStorage.getItem('peek_lang')) {
        const browserLang = navigator.language.substring(0, 2);
        if (browserLang === 'en') currentLang = 'en';
        if (browserLang === 'ja') currentLang = 'ja';
    }

    // Initialize
    setLanguage(currentLang);

    // Event Listeners
    document.querySelectorAll('.lang-dropdown a').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const lang = e.target.getAttribute('data-lang');
            setLanguage(lang);
        });
    });
});

function setLanguage(lang) {
    // Safe check
    if (!translations[lang]) lang = 'zh';

    // Save preference
    localStorage.setItem('peek_lang', lang);

    // Update Text Content
    document.querySelectorAll('[data-i18n]').forEach(element => {
        const key = element.getAttribute('data-i18n');
        if (translations[lang][key]) {
            element.textContent = translations[lang][key];
        }
    });

    // Update Lang Switcher UI
    const labels = {
        'zh': '中文',
        'en': 'English',
        'ja': '日本語'
    };
    document.querySelector('.current-lang').textContent = labels[lang];
    document.documentElement.lang = lang;
}
