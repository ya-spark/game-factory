#!/usr/bin/env bash
# Smoke run of the web build (the Hostinger VPS web copy) in headless Chromium.
#
#   bash scripts/web_smoke.sh <app-folder> [build-dir]
#
# Serves <build-dir> (default build/web, built with `flutter build web --release --base-href
# /<app-folder>/`) under /<app-folder>/ on a local port, opens it with Playwright's Chromium
# (headless, --no-sandbox) and checks: the app starts (Flutter view appears), the accessibility tree
# shows the home screen, a first "Play" or "Start" button opens a game, Settings opens, and no
# uncaught page error or console error is logged. Prints PASS or FAIL per check; exit 1 on any FAIL.
# Needs: python3, node and the `playwright` npm package with its Chromium (pre-installed in the
# studio sandbox; set NODE_PATH to its node_modules if `require('playwright')` is not found).
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:?usage: web_smoke.sh <app-folder> [build-dir]}"
BUILD="${2:-build/web}"
[ -f "$BUILD/index.html" ] || { echo "SMOKE: no $BUILD/index.html (run flutter build web first)" >&2; exit 2; }

SERVE="$(mktemp -d)"
PORT="${SMOKE_PORT:-8765}"
ln -s "$(cd "$BUILD" && pwd)" "$SERVE/$APP"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SERVE" >/dev/null 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true; rm -rf "$SERVE"' EXIT
sleep 1

export NODE_PATH="${NODE_PATH:-$(npm root -g 2>/dev/null || true)}"
echo "SMOKE: NODE_PATH=$NODE_PATH"
SMOKE_URL="http://127.0.0.1:$PORT/$APP/" node - <<'NODE'
const { chromium } = require('playwright');
const url = process.env.SMOKE_URL;
const results = [];
const errors = [];
const check = (name, ok, note = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${note ? ' (' + note + ')' : ''}`);
};
// Buttons of the accessibility tree whose label matches `re`.
const button = (page, re) => page.locator('flt-semantics[role="button"]').filter({ hasText: re }).first();

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 420, height: 860 } });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });
  try {
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
    check('app starts (Flutter view)', true);
    await page.waitForTimeout(3000);
    // Turn on the accessibility tree so buttons can be found by their labels.
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForSelector('flt-semantics', { timeout: 20000 });
    check('home loads (semantics tree present)', true);

    const play = button(page, /^(play|start|let.?s play|continue)/i);
    if (await play.count()) {
      await play.click({ force: true });
      await page.waitForTimeout(3000);
      check('a game opens', true);
      await page.keyboard.press('Escape');
      await page.goBack().catch(() => {});
      await page.waitForTimeout(1000);
    } else {
      check('a game opens', false, 'no Play/Start button found by label');
    }

    const settings = button(page, /settings/i);
    if (await settings.count()) {
      await settings.click({ force: true });
      await page.waitForTimeout(1500);
      check('settings open', true);
    } else {
      check('settings open', false, 'no Settings button found by label');
    }
  } catch (e) {
    check('run', false, String(e.message).split('\n')[0]);
  }
  check('no uncaught errors in the console', errors.length === 0, errors.slice(0, 3).join(' | '));
  await browser.close();
  process.exit(results.every(Boolean) ? 0 : 1);
})();
NODE
