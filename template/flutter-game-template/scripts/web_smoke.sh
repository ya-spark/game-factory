#!/usr/bin/env bash
# Smoke run of the web build (the Hostinger VPS web copy) in headless Chromium.
#
#   bash scripts/web_smoke.sh <app-folder> [build-dir]
#
# Build first: `flutter build web --release --no-web-resources-cdn --base-href /<app-folder>/`
# (--no-web-resources-cdn bundles CanvasKit so the app does not need a Google CDN). The script serves
# <build-dir> under /<app-folder>/ on a local port and opens it with Playwright's Chromium
# (headless, --no-sandbox). Requests to the content host (content.activemindcraft.com) are answered
# from the app's own bundled content (assets/content), so no network is needed and content is the
# same as the built-in packs. Checks, each PASS or FAIL (exit 1 on any FAIL):
#   - the app starts (Flutter view appears) and the accessibility tree is on
#   - first run: if the "New player" screen shows (Craft apps), a nickname, an avatar and the first
#     year are chosen and "Start" is pressed
#   - home loads (a Settings, Games or Play button is there)
#   - a game or lesson opens: Craft apps open the first topic in Study, hubs open the first game
#   - Settings open (skipped, and said so, when the app has no Settings button)
#   - no uncaught page error and no console error (the content host being blocked is not counted)
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
SMOKE_URL="http://127.0.0.1:$PORT/$APP/" SMOKE_BUILD="$(cd "$BUILD" && pwd)" node - <<'NODE'
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const url = process.env.SMOKE_URL;
const results = [];
const errors = [];
const check = (name, ok, note = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${note ? ' (' + note + ')' : ''}`);
};

// The accessibility tree (flt-semantics) element whose label matches `re` (and role is one of
// `roles`), as a click point. Labels sit in aria-label or in the text.
async function find(page, re, roles) {
  return page.evaluate(({ src, flags, roles }) => {
    const rx = new RegExp(src, flags);
    for (const e of document.querySelectorAll('flt-semantics')) {
      const role = e.getAttribute('role') || '';
      if (roles && !roles.includes(role)) continue;
      const t = (e.getAttribute('aria-label') || e.textContent || '').trim();
      if (!rx.test(t)) continue;
      const r = e.getBoundingClientRect();
      if (r.width < 2 || r.height < 2) continue;
      return { x: r.x + r.width / 2, y: r.y + r.height / 2, t, role };
    }
    return null;
  }, { src: re.source, flags: re.flags, roles });
}
async function tap(page, re, roles) {
  const f = await find(page, re, roles);
  if (f) await page.mouse.click(f.x, f.y);
  return f;
}
async function waitFor(page, re, roles, ms = 8000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await find(page, re, roles)) return true;
    await page.waitForTimeout(250);
  }
  return false;
}

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 420, height: 860 } });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error' && !/content\.activemindcraft\.com|Failed to load resource/.test(m.text())) {
      errors.push('console: ' + m.text());
    }
  });
  // Content host: answer from the bundled content so the run needs no network.
  await page.route('**/content.activemindcraft.com/**', async (r) => {
    const m = r.request().url().match(/\/v1\/[^/]+\/([^?]*)/);
    const f = m && path.join(process.env.SMOKE_BUILD, 'assets/assets/content', m[1]);
    const cors = { 'access-control-allow-origin': '*' };
    if (f && fs.existsSync(f)) {
      return r.fulfill({ status: 200, body: fs.readFileSync(f), headers: { ...cors, 'content-type': 'application/json' } });
    }
    return r.fulfill({ status: 404, headers: cors, body: '' });
  });
  try {
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
    check('app starts (Flutter view)', true);
    await page.waitForTimeout(3000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForSelector('flt-semantics', { timeout: 20000 });
    check('accessibility tree on', true);

    // First run (Craft apps): New player screen.
    if (await waitFor(page, /^New player$/, null, 4000)) {
      await page.locator('flt-semantics input, flt-semantics textarea').first().fill('Tester', { force: true });
      await tap(page, /^(fox|owl|bear|cat|frog|panda|rabbit|penguin)$/, ['checkbox']);
      const y = await tap(page, /^(Foundation|Year \d+)$/, ['checkbox']);
      await page.waitForTimeout(500);
      const s = await tap(page, /^Start$/, ['button']);
      check('first run: New player completed', !!(y && s), y ? y.t : 'no year chip');
      await page.waitForTimeout(3000);
    }

    const home = await waitFor(page, /^(Settings|Games|Play)$/, ['button'], 15000);
    check('home loads (Settings, Games or Play button present)', home);

    // A game or lesson: Craft apps have Study with topic buttons; hubs list games.
    let opened = false;
    if (await tap(page, /^Study$/, ['button'])) {
      await page.waitForTimeout(1500);
      if (await waitFor(page, /, (english|maths), /i, ['button'], 10000)) {
        await tap(page, /, (english|maths), /i, ['button']);
        await page.waitForTimeout(2500);
        opened = !(await find(page, /^Learn$/, ['button'])) || !!(await find(page, /^(Check|Next|Skip|Answer|Back)/i, ['button']));
      }
    } else {
      // Hubs: first game tile (a button that is not navigation or settings).
      const f = await tap(page, /^(?!Settings$|Games$|Challenges$|Shop$|Back$|Play$|Continue).+/, ['button']);
      await page.waitForTimeout(3000);
      // A game screen replaces the home tabs.
      opened = !!f && !(await find(page, /^Challenges$/, ['button']));
    }
    check('a game or lesson opens', opened);

    // Settings: reach the header button again (go Back first when a screen is open).
    for (let i = 0; i < 3 && !(await find(page, /^Settings$/, ['button'])); i++) {
      if (!(await tap(page, /^(Leave|Back|Close|Quit|Exit)/i, ['button']))) await page.keyboard.press('Escape');
      await page.waitForTimeout(1200);
      // A confirm dialog may ask whether to leave.
      await tap(page, /^(Leave|Yes|Quit|Exit|OK)\b/i, ['button']);
      await page.waitForTimeout(800);
    }
    const settings = await tap(page, /^Settings$/, ['button']);
    if (settings) {
      await page.waitForTimeout(2000);
      check('settings open', !!(await find(page, /^(Sound|Music|Vibration|Switch player|Grown-ups)/i, null)));
    } else {
      console.log('SKIP  settings open (this app has no Settings button on its home screen)');
    }
  } catch (e) {
    check('run', false, String(e.message).split('\n')[0]);
  }
  check('no uncaught errors in the console', errors.length === 0, errors.slice(0, 3).join(' | '));
  await browser.close();
  process.exit(results.every(Boolean) ? 0 : 1);
})();
NODE
