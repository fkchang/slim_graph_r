#!/usr/bin/env node
'use strict';

const assert = require('assert');
const path = require('path');
const { chromium } = require('playwright');
const { assertIntendedFonts, installFontRoutes, loadFontAssets } = require('./parity_fonts');

const root = path.resolve(__dirname, '..');

(async () => {
  const bundle = loadFontAssets(root);
  const corrupted = { ...bundle.manifest, faces: [{ ...bundle.manifest.faces[0], sha256: '0'.repeat(64) }] };
  assert.throws(() => loadFontAssets(root, corrupted), /SHA-256 mismatch/, 'font hash mismatch must fail before capture');

  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'en-US', timezoneId: 'UTC' });
    const served = await installFontRoutes(context, bundle);
    const page = await context.newPage();
    const failures = [];
    page.on('requestfailed', (request) => { if (/^https?:\/\//.test(request.url())) failures.push({ url: request.url(), error: request.failure()?.errorText || 'unknown' }); });
    await page.goto(`file://${path.join(root, 'vendor/diagram-design/assets/v0-baseline/example-architecture-full.html')}`, { waitUntil: 'load' });
    const fonts = await assertIntendedFonts(page, bundle);
    assert.equal(failures.length, 0, `external resource failures: ${JSON.stringify(failures)}`);
    assert.equal(served.filter((entry) => entry.kind === 'font').length, bundle.assets.length, 'each pinned face must be served locally');
    assert(fonts.checks.every((face) => face.loaded), 'every intended face must be reported loaded');
    await context.close();
  } finally {
    await browser.close();
  }
  console.log('parity fonts: OK (four pinned faces served locally; fallback and hash mismatch are fatal)');
})().catch((error) => { console.error(`parity fonts check failed: ${error.stack || error.message}`); process.exit(1); });
