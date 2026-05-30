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
// connected + a target selector) rather than timeouts. Output is written to ../../guides/assets/.

import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "..", "..", "guides", "assets");
const BASE_URL = (process.env.BASE_URL || "http://localhost:4000").replace(/\/$/, "");

const VIEWPORT = { width: 1440, height: 900 };
const DEVICE_SCALE = 2;

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

// Each shot: a file name, the path to visit, the selector that proves the screen is ready, an
// optional interaction (prepare), and whether to capture the full scrollable page or just the
// viewport (use viewport for modal/overlay shots so the overlay stays in frame).
const SHOTS = [
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
  {
    file: "02-operator-inbox.png",
    path: "/support",
    waitFor: "text=Trailmark",
    fullPage: true,
  },
  {
    // The conversation workspace: timeline, customer-context rail, AI draft, and governed actions.
    // The ⌘K knowledge-base search palette lives here too, but ⌘K / Ctrl+K are browser-reserved
    // shortcuts a headless browser swallows, so it's exercised live in the demo, not captured here.
    file: "03-conversation-workspace.png",
    path: "/support/1",
    waitFor: ".message-card",
    fullPage: true,
  },
  { file: "04-approve-draft.png", path: "/support/17", waitFor: "text=Approve & Send", fullPage: true },
  { file: "05-action-pending.png", path: "/support/18", waitFor: ".message-card", fullPage: true },
  { file: "06-action-executed.png", path: "/support/19", waitFor: "text=Action completed", fullPage: true },
  { file: "07-resolved-conversation.png", path: "/support/13", waitFor: "text=Trailmark", fullPage: true },
  { file: "08-outbound-recovery.png", path: "/support/20", waitFor: "text=Outbound recovery", fullPage: true },
  {
    file: "09-bulk-recovery.png",
    path: "/support",
    waitFor: "input[phx-click='toggle_select']",
    fullPage: false,
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
  { file: "10-knowledge-base.png", path: "/support/knowledge-base", waitFor: "text=Trailmark", fullPage: true },
  { file: "11-knowledge-gaps.png", path: "/support/knowledge-base/gaps", waitFor: "body", fullPage: true },
  { file: "12-audit-log.png", path: "/support/audit-log", waitFor: "text=demo_operator", fullPage: true },
  { file: "13-settings.png", path: "/support/settings", waitFor: "body", fullPage: true },
];

async function waitForLiveViewConnected(page) {
  // LiveView adds `.phx-connected` to the root element once the socket is live; if the page has
  // no LiveView (e.g. a dead view) this resolves quickly via the fallback timeout.
  await page
    .waitForFunction(() => document.querySelector(".phx-connected") !== null, { timeout: 4000 })
    .catch(() => {});
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });

  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE,
    reducedMotion: "reduce",
    colorScheme: "light",
  });
  await context.addInitScript((css) => {
    const style = document.createElement("style");
    style.textContent = css;
    document.documentElement.appendChild(style);
  }, STABILIZE_CSS);

  const page = await context.newPage();
  let ok = 0;
  const failures = [];

  for (const shot of SHOTS) {
    const url = `${BASE_URL}${shot.path}`;
    try {
      await page.goto(url, { waitUntil: "networkidle", timeout: 20000 });
      await waitForLiveViewConnected(page);
      if (shot.waitFor) {
        await page.locator(shot.waitFor).first().waitFor({ state: "visible", timeout: 8000 });
      }
      if (shot.prepare) await shot.prepare(page);
      await page.waitForTimeout(150); // settle layout after any interaction
      await page.screenshot({
        path: join(OUT_DIR, shot.file),
        fullPage: Boolean(shot.fullPage),
      });
      ok += 1;
      console.log(`  ✓ ${shot.file.padEnd(30)} ${shot.path}`);
    } catch (err) {
      failures.push({ shot, err });
      console.error(`  ✗ ${shot.file.padEnd(30)} ${shot.path}  — ${err.message.split("\n")[0]}`);
    }
  }

  await browser.close();
  console.log(`\n${ok}/${SHOTS.length} screenshots written to guides/assets/`);
  if (failures.length) {
    console.error(`${failures.length} failed. Is the seeded demo running at ${BASE_URL}? (mix ecto.reset && mix phx.server)`);
    process.exit(1);
  }
}

main();
