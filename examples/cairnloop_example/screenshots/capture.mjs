// Deterministic screenshot capture of the Cairnloop demo app.
//
// This is a CAPTURE-ONLY tool: it drives the already-seeded demo with a real browser and saves
// PNGs. It asserts nothing and is NOT part of CI's gating lane — so the project's locked
// "no Wallaby / no browser assertions in CI" decision (Chrome-in-CI flake) stays fully intact.
// The deterministic golden-path test (test/integration/golden_path_test.exs, Phoenix.LiveViewTest)
// remains the single source of CI truth.
//
// Usage:
//   1. Boot the seeded demo:  (cd .. && mix ecto.reset && mix phx.server)
//   2. Capture:               BASE_URL=http://localhost:4000 npm run capture
//
// Determinism controls: fixed viewport + device scale, reduced motion, an injected stylesheet
// that kills animations/transitions/caret-blink, and waits on concrete conditions (LiveView
// connected + a target selector) rather than timeouts. Phase 45 evidence output is written to
// ../../guides/assets/light/ and ../../guides/assets/dark/. Root-level light copies are kept only
// for existing guide references.

import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "..", "..", "guides", "assets");
const BASE_URL = (process.env.BASE_URL || "http://localhost:4000").replace(/\/$/, "");

const VIEWPORT = { width: 1440, height: 900 };
const DEVICE_SCALE = 2;
const THEMES = [
  { name: "light", colorScheme: "light" },
  { name: "dark", colorScheme: "dark" },
];

// Injected before every shot: neutralize the usual sources of pixel drift.
const STABILIZE_CSS = `
  *, *::before, *::after {
    animation-duration: 0s !important;
    animation-delay: 0s !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    caret-color: transparent !important;
    scroll-behavior: auto !important;
  }
`;

function themeOutputDir(themeName) {
  return join(OUT_DIR, themeName);
}

// Each shot: a file name, the path to visit, the selector that proves the screen is ready, an
// optional interaction (prepare), and whether to capture the full scrollable page or just the
// viewport (use viewport for modal/overlay shots so the overlay stays in frame). `rootCompat`
// writes a light-theme root-level copy for existing guide references; Phase 45 acceptance uses the
// theme directories.
const SHOTS = [
  {
    // Cockpit Home — the task-oriented landing the operator lands on at the mount root.
    file: "02-cockpit-home.png",
    path: "/support",
    waitFor: "text=Welcome back",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "02b-operator-inbox.png",
    path: "/support/inbox",
    waitFor: "text=Inbox",
    fullPage: true,
    rootCompat: true,
  },
  {
    // The conversation workspace: timeline, customer-context rail, AI draft, and governed actions.
    // The ⌘K knowledge-base search palette lives here too, but ⌘K / Ctrl+K are browser-reserved
    // shortcuts a headless browser swallows, so it's exercised live in the demo, not captured here.
    file: "03-conversation-workspace.png",
    path: "/support/1",
    waitFor: ".message-card",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "04-approve-draft.png",
    path: "/support/17",
    waitFor: "text=Approve & Send",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "05-action-pending.png",
    path: "/support/18",
    waitFor: ".message-card",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "06-action-executed.png",
    path: "/support/19",
    waitFor: "text=Action completed",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "06b-action-rejected.png",
    path: "/support/18",
    waitFor: "text=Rejected for screenshot proof",
    fullPage: true,
  },
  {
    file: "06c-action-deferred.png",
    path: "/support/20",
    waitFor: "text=Deferred until the customer confirms",
    fullPage: true,
  },
  {
    file: "07-resolved-conversation.png",
    path: "/support/13",
    waitFor: "text=Trailmark",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "08-outbound-recovery.png",
    path: "/support/20",
    waitFor: "text=Outbound recovery",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "09-bulk-recovery.png",
    path: "/support/inbox",
    waitFor: "input[phx-click='toggle_select']",
    fullPage: false,
    rootCompat: true,
    async prepare(page) {
      // Select two resolved conversations and open the bulk-recovery confirm modal.
      for (const id of [13, 14]) {
        await page.locator(`input[phx-click='toggle_select'][phx-value-id='${id}']`).click().catch(() => {});
      }
      const openBtn = page.locator("button[phx-click='open_bulk_confirm']").first();
      await openBtn.click().catch(() => {});
      await page.locator("button[phx-click='confirm_bulk_send']").first()
        .waitFor({ state: "visible", timeout: 5000 }).catch(() => {});
    },
  },
  {
    file: "10-knowledge-base.png",
    path: "/support/knowledge-base",
    waitFor: "text=Trailmark",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "11-knowledge-gaps.png",
    path: "/support/knowledge-base/gaps",
    waitFor: "body",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "11b-kb-suggestions.png",
    path: "/support/knowledge-base/suggestions",
    waitFor: "body",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "11c-kb-editor.png",
    path: "/support/knowledge-base/1/edit",
    waitFor: "body",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "12-audit-log.png",
    path: "/support/audit-log",
    waitFor: "text=Audit Log",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "13-settings.png",
    path: "/support/settings",
    waitFor: "body",
    fullPage: true,
    rootCompat: true,
  },
  {
    file: "14-audit-empty-state.png",
    path: "/support/audit-log",
    waitFor: "text=Audit Log",
    fullPage: true,
    async prepare(page) {
      await page.locator("input[aria-label='Search audit events']").fill("phase45-empty-audit-filter");
      await page.waitForTimeout(250);
      await page.locator("text=No audit events found").first()
        .waitFor({ state: "visible", timeout: 8000 });
    },
  },
];

const ROOT_COMPAT_ONLY_SHOTS = [
  {
    file: "00-demo-index.png",
    path: "/",
    waitFor: "text=Support that leaves a trail",
    fullPage: true,
  },
  {
    file: "01-customer-chat.png",
    path: "/chat",
    waitFor: "form, [phx-submit], input, textarea",
    fullPage: false,
  },
];

async function waitForLiveViewConnected(page) {
  // LiveView adds `.phx-connected` to the root element once the socket is live; if the page has
  // no LiveView (e.g. a dead view) this resolves quickly via the fallback timeout.
  await page
    .waitForFunction(() => document.querySelector(".phx-connected") !== null, { timeout: 4000 })
    .catch(() => {});
}

async function applyThemeState(page, themeName) {
  await page.addInitScript(({ css, themeName }) => {
    localStorage.setItem("phx:theme", themeName);
    document.documentElement.dataset.theme = themeName;

    const style = document.createElement("style");
    style.textContent = css;
    document.documentElement.appendChild(style);
  }, { css: STABILIZE_CSS, themeName });
}

async function reinforceThemeState(page, themeName) {
  await page.evaluate((themeName) => {
    localStorage.setItem("phx:theme", themeName);
    document.documentElement.dataset.theme = themeName;
    window.dispatchEvent(new CustomEvent("phx:set-theme"));
  }, themeName).catch(() => {});
}

async function openConversationBySubject(page, subject) {
  await page.locator("a", { hasText: subject }).first().click();
  await waitForLiveViewConnected(page);
  await page.locator(".message-card").first().waitFor({ state: "visible", timeout: 8000 });
}

async function captureShot(context, shot, themeName, outputPath) {
  const page = await context.newPage();
  const url = `${BASE_URL}${shot.path}`;

  try {
    await applyThemeState(page, themeName);
    await page.goto(url, { waitUntil: "networkidle", timeout: 20000 });
    await waitForLiveViewConnected(page);
    await reinforceThemeState(page, themeName);
    if (shot.waitFor) {
      await page.locator(shot.waitFor).first().waitFor({ state: "visible", timeout: 8000 });
    }
    if (shot.prepare) await shot.prepare(page);
    await reinforceThemeState(page, themeName);
    await page.waitForTimeout(150); // settle layout after any interaction
    await page.screenshot({
      path: outputPath,
      fullPage: Boolean(shot.fullPage),
    });
  } finally {
    await page.close();
  }
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });

  const browser = await chromium.launch();
  let ok = 0;
  const failures = [];

  for (const theme of THEMES) {
    const outDir = themeOutputDir(theme.name);
    await mkdir(outDir, { recursive: true });

    const context = await browser.newContext({
      viewport: VIEWPORT,
      deviceScaleFactor: DEVICE_SCALE,
      reducedMotion: "reduce",
      colorScheme: theme.colorScheme,
    });

    for (const shot of SHOTS) {
      try {
        await captureShot(context, shot, theme.name, join(outDir, shot.file));
        ok += 1;
        console.log(`  ✓ ${theme.name}/${shot.file.padEnd(30)} ${shot.path}`);

        if (theme.name === "light" && shot.rootCompat) {
          await captureShot(context, shot, theme.name, join(OUT_DIR, shot.file));
          ok += 1;
          console.log(`  ✓ ${shot.file.padEnd(30)} ${shot.path} (root light copy)`);
        }
      } catch (err) {
        failures.push({ theme, shot, err });
        console.error(
          `  ✗ ${theme.name}/${shot.file.padEnd(30)} ${shot.path}  — ${err.message.split("\n")[0]}`
        );
      }
    }

    if (theme.name === "light") {
      for (const shot of ROOT_COMPAT_ONLY_SHOTS) {
        try {
          await captureShot(context, shot, theme.name, join(OUT_DIR, shot.file));
          ok += 1;
          console.log(`  ✓ ${shot.file.padEnd(30)} ${shot.path} (docs root light copy)`);
        } catch (err) {
          failures.push({ theme, shot, err });
          console.error(
            `  ✗ ${shot.file.padEnd(30)} ${shot.path}  — ${err.message.split("\n")[0]}`
          );
        }
      }
    }

    await context.close();
  }

  await browser.close();
  console.log(`\n${ok} screenshots written to guides/assets/{light,dark}/`);
  if (failures.length) {
    console.error(
      `${failures.length} failed. Is the seeded demo running at ${BASE_URL}? ` +
        "(mix ecto.reset && mix phx.server)"
    );
    process.exit(1);
  }
}

main();
