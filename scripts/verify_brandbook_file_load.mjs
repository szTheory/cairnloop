import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const brandbookPath = join(projectRoot, "brandbook", "index.html");
const brandbookUrl = pathToFileURL(brandbookPath).href;
const playwrightPath = join(
  projectRoot,
  "examples",
  "cairnloop_example",
  "assets",
  "node_modules",
  "playwright",
  "index.mjs",
);

const { chromium } = await import(pathToFileURL(playwrightPath).href);

const requiredText = [
  "Cairnloop brand book",
  "Support that leaves a trail.",
  "Canonical source: priv/static/cairnloop.css :root",
  "Token status: derived from canonical CSS",
  "Network dependency: none",
  "Brandbook is git-tracked and unshipped",
  "Logo-family sign-off remains before Phase 52 wiring",
  "Voice and Microcopy",
  "Brandbook asset failed to load. Check relative paths, regenerate tokens from priv/static/cairnloop.css, and rerun the file-load verification.",
];

const requiredSections = [
  "#color",
  "#typography",
  "#tokens",
  "#logo",
  "#voice",
  "#microcopy",
  "#imagery",
  "#motion",
  "#downloads",
  "#footer",
];

const requiredLocalAssets = [
  "../logo/cairnloop-lockup-horizontal.svg",
  "../logo/cairnloop-mark.svg",
  "../logo/favicon.ico",
  "../logo/cairnloop-og.png",
];

const viewports = [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1280, height: 900 },
];

const failures = [];
const requests = [];
const failedRequests = [];
const consoleMessages = [];
const pageErrors = [];

function fail(message) {
  failures.push(message);
}

function assertLocalAsset(relativePath) {
  const filePath = resolve(projectRoot, "brandbook", relativePath);

  if (!existsSync(filePath)) {
    fail(
      `Missing local asset ${relativePath}: selector/link expected a committed file. Next action: restore ${filePath} or regenerate the brandbook.`,
    );
  }
}

async function hasVisibleFocus(page, selector, stateName) {
  const target = page.locator(selector).first();
  await target.focus();

  return target.evaluate((element) => {
    const style = window.getComputedStyle(element);
    return {
      outline: style.outlineStyle !== "none" && style.outlineWidth !== "0px",
      boxShadow: style.boxShadow !== "none",
    };
  }).then((style) => {
    if (!style.outline && !style.boxShadow) {
      fail(`Missing visible focus style for ${selector} during ${stateName}. Next action: check brandbook.css focus-visible rules.`);
    }
  });
}

async function verifyViewport(browser, viewport) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    reducedMotion: "reduce",
    colorScheme: "light",
  });

  const page = await context.newPage();

  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleMessages.push(`${viewport.name}: ${message.type()}: ${message.text()}`);
    }
  });

  page.on("pageerror", (error) => {
    pageErrors.push(`${viewport.name}: ${error.message}`);
  });

  page.on("request", (request) => {
    requests.push(request.url());
  });

  page.on("requestfailed", (request) => {
    failedRequests.push(`${viewport.name}: ${request.url()} ${request.failure()?.errorText || "request failed"}`);
  });

  try {
    await page.goto(brandbookUrl, { waitUntil: "load", timeout: 15000 });

    const bodyText = await page.locator("body").innerText();
    if (bodyText.trim().length < 2000) {
      fail(`${viewport.name}: body appears blank or truncated. Next action: inspect brandbook/index.html generation.`);
    }

    for (const text of requiredText) {
      if (!bodyText.includes(text)) fail(`${viewport.name}: missing required text ${JSON.stringify(text)}`);
    }

    const bodyBox = await page.locator("body").boundingBox();
    const headerBox = await page.locator(".brandbook-header").boundingBox();
    const colorBox = await page.locator("#color").boundingBox();

    if (!bodyBox || bodyBox.width <= 0 || bodyBox.height <= 0) fail(`${viewport.name}: body has no visible geometry.`);
    if (!headerBox || headerBox.width <= 0 || headerBox.height <= 0) fail(`${viewport.name}: .brandbook-header is not visible.`);
    if (!colorBox || colorBox.width <= 0 || colorBox.height <= 0) fail(`${viewport.name}: #color section is not visible.`);

    for (const selector of requiredSections) {
      const box = await page.locator(selector).boundingBox();
      if (!box || box.width <= 0 || box.height <= 0) {
        fail(`${viewport.name}: ${selector} has no visible bounding box. Next action: check generated HTML and brandbook.css.`);
      }
    }

    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    if (overflow > 4) {
      fail(`${viewport.name}: document has ${overflow}px horizontal overflow. Next action: inspect responsive table/logo sizing.`);
    }

    const darkButton = page.getByRole("button", { name: "Dark" });
    const lightButton = page.getByRole("button", { name: "Light" });

    await darkButton.click();
    const darkTheme = await page.locator("html").getAttribute("data-theme");
    const darkPressed = await darkButton.getAttribute("aria-pressed");
    if (darkTheme !== "dark" || darkPressed !== "true") {
      fail(`${viewport.name}: Dark theme toggle did not set html[data-theme="dark"] and aria-pressed=true.`);
    }

    await lightButton.click();
    const lightTheme = await page.locator("html").getAttribute("data-theme");
    const lightPressed = await lightButton.getAttribute("aria-pressed");
    if (lightTheme !== "light" || lightPressed !== "true") {
      fail(`${viewport.name}: Light theme toggle did not restore html[data-theme="light"] and aria-pressed=true.`);
    }

    await page.keyboard.press("Tab");
    await hasVisibleFocus(page, '[data-theme-choice="light"]', `${viewport.name} theme toggle`);
    await hasVisibleFocus(page, 'a[href="../logo/cairnloop-lockup-horizontal.svg"]', `${viewport.name} download link`);

    for (const relativePath of requiredLocalAssets) {
      assertLocalAsset(relativePath);

      const linkCount = await page.locator(`a[href="${relativePath}"]`).count();
      if (linkCount < 1) {
        fail(`${viewport.name}: missing download link ${relativePath}. Next action: regenerate brandbook/index.html.`);
      }

      const image = page.locator(`img[src="${relativePath}"]`).first();
      if ((await image.count()) > 0) {
        await image.scrollIntoViewIfNeeded();
        const imageState = await image.evaluate((element) => ({
          complete: element.complete,
          naturalWidth: element.naturalWidth,
          naturalHeight: element.naturalHeight,
        }));

        if (!imageState.complete || imageState.naturalWidth <= 0 || imageState.naturalHeight <= 0) {
          fail(`${viewport.name}: image ${relativePath} failed to resolve from file://. Next action: check the committed logo asset path.`);
        }
      }
    }
  } catch (error) {
    fail(`${viewport.name}: navigation or assertion failed for ${brandbookUrl}: ${error.message}`);
  } finally {
    await context.close();
  }
}

const browser = await chromium.launch();

try {
  for (const viewport of viewports) {
    await verifyViewport(browser, viewport);
  }
} finally {
  await browser.close();
}

const remoteRequests = requests.filter((url) => /^https?:\/\//.test(url));
const nonLocalRequests = requests.filter((url) => !url.startsWith("file://") && !url.startsWith("data:"));

if (consoleMessages.length) fail(`Console errors:\n${consoleMessages.join("\n")}`);
if (pageErrors.length) fail(`Page errors:\n${pageErrors.join("\n")}`);
if (failedRequests.length) fail(`Failed requests:\n${failedRequests.join("\n")}`);
if (remoteRequests.length) fail(`Remote requests:\n${remoteRequests.join("\n")}`);
if (nonLocalRequests.length) fail(`Non-local requests:\n${nonLocalRequests.join("\n")}`);

if (failures.length) {
  console.error(`brandbook file-url verification failed for ${brandbookUrl}`);
  console.error(failures.join("\n\n"));
  process.exit(1);
}

console.log(`brandbook file-url verification passed: ${brandbookUrl}`);
