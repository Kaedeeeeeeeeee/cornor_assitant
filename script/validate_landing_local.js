#!/usr/bin/env node
const { spawn } = require("node:child_process");
const { once } = require("node:events");
const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");
const { chromium } = require("playwright");

const rootDir = path.resolve(__dirname, "..");
const landingDir = path.join(rootDir, "CornerAssistantApp", "landing-page");
let port = Number(process.env.PEEK_LANDING_PORT || 0);
let baseURL = "";
const forbiddenCopy = ["Bing", "selected text", "Selected text", "选中文字", "macOS 14", "Sonoma"];

const viewports = [
  { name: "desktop", width: 1440, height: 1000 },
  { name: "tablet", width: 1024, height: 900 },
  { name: "mobile", width: 390, height: 900 },
];

function fail(message) {
  throw new Error(message);
}

async function findAvailablePort() {
  const server = net.createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  const availablePort = typeof address === "object" && address ? address.port : 0;
  server.close();
  await once(server, "close");
  if (!availablePort) fail("could not allocate a local landing validation port");
  return availablePort;
}

function startServer() {
  const child = spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1"], {
    cwd: landingDir,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let stderr = "";
  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString();
  });

  child.on("exit", (code) => {
    if (code !== 0 && code !== null) {
      console.error(`landing server exited with ${code}: ${stderr.trim()}`);
    }
  });

  return child;
}

async function waitForServer() {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(baseURL, { method: "HEAD" });
      if (response.ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  fail(`local landing server did not become ready at ${baseURL}`);
}

async function expectOK(page, url) {
  const response = await page.goto(url, { waitUntil: "domcontentloaded" });
  if (!response || response.status() !== 200) {
    fail(`${url} returned ${response ? response.status() : "no response"}`);
  }
}

async function validatePage(page, pageName, url) {
  const consoleErrors = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => {
    consoleErrors.push(error.message);
  });

  await expectOK(page, url);

  const result = await page.evaluate((forbidden) => {
    const doc = document.documentElement;
    const bodyText = document.body.innerText || "";
    const imageStates = [...document.images].map((image) => ({
      src: image.getAttribute("src") || image.currentSrc,
      ok: image.complete && image.naturalWidth > 0,
      width: image.naturalWidth,
      height: image.naturalHeight,
    }));
    return {
      title: document.title,
      htmlLang: doc.lang,
      horizontalOverflow: doc.scrollWidth > doc.clientWidth + 1,
      missingImages: imageStates.filter((image) => !image.ok),
      forbiddenHits: forbidden.filter((term) => bodyText.includes(term)),
      h1: document.querySelector("h1")?.textContent?.trim() || "",
    };
  }, forbiddenCopy);

  if (!result.title) fail(`${pageName} has no title`);
  if (!result.htmlLang) fail(`${pageName} has no html lang`);
  if (result.horizontalOverflow) fail(`${pageName} has horizontal overflow`);
  if (result.missingImages.length > 0) {
    fail(`${pageName} has missing images: ${JSON.stringify(result.missingImages)}`);
  }
  if (result.forbiddenHits.length > 0) {
    fail(`${pageName} contains forbidden copy: ${result.forbiddenHits.join(", ")}`);
  }
  if (consoleErrors.length > 0) {
    fail(`${pageName} console errors: ${consoleErrors.join(" | ")}`);
  }

  return result;
}

async function validateLanguageSwitching(page) {
  await expectOK(page, baseURL);

  const expectations = [
    { lang: "zh", htmlLang: "zh-CN", h1: "隐于无形，触手可及。" },
    { lang: "en", htmlLang: "en", h1: "Out of sight. Right when you need it." },
    { lang: "ja", htmlLang: "ja", h1: "ふだんは静かに。必要な時だけすぐに。" },
  ];

  for (const expectation of expectations) {
    const selector = `button[data-lang="${expectation.lang}"]`;
    await page.click(selector);
    const state = await page.evaluate(() => ({
      htmlLang: document.documentElement.lang,
      h1: document.querySelector("h1")?.textContent?.trim() || "",
      activeLanguage: document.querySelector(".language-switcher button[aria-pressed='true']")?.getAttribute("data-lang"),
    }));

    if (state.htmlLang !== expectation.htmlLang) {
      fail(`language ${expectation.lang} expected html lang ${expectation.htmlLang}, got ${state.htmlLang}`);
    }
    if (state.h1 !== expectation.h1) {
      fail(`language ${expectation.lang} expected h1 ${expectation.h1}, got ${state.h1}`);
    }
    if (state.activeLanguage !== expectation.lang) {
      fail(`language ${expectation.lang} was not marked active`);
    }
  }
}

async function validateStaticAssets(page) {
  for (const relativePath of ["robots.txt", "sitemap.xml", "site.webmanifest", "assets/icon.png", "assets/social-preview.png"]) {
    const response = await page.goto(`${baseURL}${relativePath}`, { waitUntil: "domcontentloaded" });
    if (!response || response.status() !== 200) {
      fail(`${relativePath} returned ${response ? response.status() : "no response"}`);
    }
  }

  const manifest = JSON.parse(fs.readFileSync(path.join(landingDir, "site.webmanifest"), "utf8"));
  if (manifest.name !== "Peek") fail("site.webmanifest name is not Peek");
}

async function main() {
  if (!port) port = await findAvailablePort();
  baseURL = `http://127.0.0.1:${port}/`;

  const server = startServer();
  try {
    await waitForServer();

    const browser = await chromium.launch({ headless: true });
    try {
      const pageResults = [];
      for (const viewport of viewports) {
        const page = await browser.newPage({ viewport });
        pageResults.push({
          viewport: viewport.name,
          home: await validatePage(page, `home ${viewport.name}`, baseURL),
        });
        await page.close();
      }

      const detailPage = await browser.newPage({ viewport: viewports[0] });
      pageResults.push({
        viewport: "desktop",
        privacy: await validatePage(detailPage, "privacy desktop", `${baseURL}privacy.html`),
      });
      await detailPage.close();

      const supportPage = await browser.newPage({ viewport: viewports[0] });
      pageResults.push({
        viewport: "desktop",
        support: await validatePage(supportPage, "support desktop", `${baseURL}support.html`),
      });
      await supportPage.close();

      const languagePage = await browser.newPage({ viewport: viewports[0] });
      await validateLanguageSwitching(languagePage);
      await validateStaticAssets(languagePage);
      await languagePage.close();

      for (const result of pageResults) {
        console.log(`landing.local.${result.viewport}: ${JSON.stringify(result)}`);
      }
      console.log("Landing local validation passed");
    } finally {
      await browser.close();
    }
  } finally {
    server.kill();
    await Promise.race([
      once(server, "exit"),
      new Promise((resolve) => setTimeout(resolve, 1000)),
    ]);
  }
}

main().catch((error) => {
  console.error(`Landing local validation failed: ${error.message}`);
  process.exit(1);
});
