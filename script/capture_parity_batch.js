#!/usr/bin/env node
'use strict';

// Development-only Playwright capture. The wrapper supplies NODE_PATH from the
// globally installed Playwright package, keeping it out of the gem runtime.
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const { assertIntendedFonts, installFontRoutes, isExternal, loadFontAssets } = require('./parity_fonts');
const { reviewCapturePlan } = require('./parity_capture_plan');

function option(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? undefined : process.argv[index + 1];
}

const root = path.resolve(__dirname, '..');
const batchPath = option('--batch');
const outputRoot = option('--output');
const generatedRoot = option('--generated');
const registryPath = option('--registry');
if (!batchPath || !outputRoot || !generatedRoot || !registryPath) {
  throw new Error('Usage: capture_parity_batch.js --batch PATH --generated PATH --output PATH --registry PATH');
}

const batch = JSON.parse(fs.readFileSync(batchPath, 'utf8'));
const index = JSON.parse(fs.readFileSync(path.join(root, 'docs/roadmap/parity-fixtures-v0.json'), 'utf8'));
const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const records = new Map(index.records.map((record) => [record.baseline_case_id, record]));
const fixtures = new Map(registry.fixtures.map((fixture) => [fixture.id, fixture]));
fs.mkdirSync(outputRoot, { recursive: true });

function rect(value) {
  return ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'].reduce((result, key) => {
    result[key] = Math.round(value[key] * 100) / 100;
    return result;
  }, {});
}

function reviewPage(result) {
  const localPanel = result.local.status === 'captured'
    ? `<figure><figcaption>SlimGraphR fixture</figcaption><img src="slimgraphr.png" alt="SlimGraphR browser capture"></figure>`
    : `<section class="unavailable"><h2>SlimGraphR fixture</h2><p>Unavailable: ${result.local.reason}</p></section>`;
  return `<!doctype html><html lang="en"><meta charset="utf-8"><title>${result.baseline_case_id} parity review</title>
<style>body{margin:0;padding:24px;background:#f5f5f5;color:#2d3142;font:16px system-ui,sans-serif}header{max-width:1800px;margin:auto}main{max-width:1800px;margin:24px auto;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}figure,.unavailable{margin:0;background:#fff;border:1px solid #bfc0c0;border-radius:8px;padding:16px;overflow:auto}figcaption,h2{font:600 14px ui-monospace,monospace;letter-spacing:.04em;text-transform:uppercase;margin:0 0 12px}img{display:block;max-width:none;width:auto}.unavailable{align-self:start;color:#4f5d75}code{font-family:ui-monospace,monospace}@media(max-width:900px){main{grid-template-columns:1fr}}</style>
<header><h1>${result.baseline_case_id}</h1><p>SHA-256 verified upstream reference. Review status: <code>${result.review_status}</code>.</p></header>
<main><figure><figcaption>Pinned Diagram Design</figcaption><img src="upstream.png" alt="Pinned Diagram Design browser capture"></figure>${localPanel}</main></html>`;
}

async function inspect(page) {
  return page.evaluate(() => {
    const rectFor = (element) => {
      const value = element.getBoundingClientRect();
      return ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'].reduce((result, key) => {
        result[key] = Math.round(value[key] * 100) / 100;
        return result;
      }, {});
    };
    const images = [...document.querySelectorAll('[role="img"], svg')]
      .filter((element, index, elements) => index === elements.indexOf(element))
      .map((element) => ({
        tag: element.tagName.toLowerCase(), role: element.getAttribute('role'), id: element.id || null,
        aria_labelledby: element.getAttribute('aria-labelledby'), aria_label: element.getAttribute('aria-label'),
        title: element.querySelector('title')?.textContent?.trim() || null,
        description: element.querySelector('desc')?.textContent?.trim() || null,
        rect: rectFor(element)
      }));
    const documentElement = document.documentElement;
    const body = document.body;
    return {
      document: { title: document.title, language: document.documentElement.lang || null },
      viewport: { width: window.innerWidth, height: window.innerHeight, device_pixel_ratio: window.devicePixelRatio },
      page: {
        client_width: documentElement.clientWidth, scroll_width: Math.max(documentElement.scrollWidth, body.scrollWidth),
        client_height: documentElement.clientHeight, scroll_height: Math.max(documentElement.scrollHeight, body.scrollHeight),
        horizontal_overflow: Math.max(documentElement.scrollWidth, body.scrollWidth) > documentElement.clientWidth,
        vertical_overflow: Math.max(documentElement.scrollHeight, body.scrollHeight) > documentElement.clientHeight
      },
      fonts: document.fonts ? { status: document.fonts.status, faces: [...document.fonts].map((face) => ({ family: face.family, status: face.status })) } : null,
      accessibility: { body_role: body.getAttribute('role'), images },
      scroll_regions: [...document.querySelectorAll('[data-sgr-scroll-container]')].map((element, index) => ({
        index, rect: rectFor(element), client_width: element.clientWidth, scroll_width: element.scrollWidth,
        client_height: element.clientHeight, scroll_height: element.scrollHeight,
        horizontal_overflow: element.scrollWidth > element.clientWidth,
        vertical_overflow: element.scrollHeight > element.clientHeight
      })),
      geometry: [...document.querySelectorAll('h1, h2, p, svg, [role="img"]')]
        .slice(0, 40).map((element) => ({ tag: element.tagName.toLowerCase(), text: element.textContent.trim().slice(0, 160), rect: rectFor(element) }))
    };
  });
}

async function prepareReviewScreenshot(page, side, evidence) {
  const plan = side === 'slimgraphr'
    ? reviewCapturePlan(evidence.scroll_regions)
    : { mode: 'full-page', wide_region_indices: [] };
  if (plan.mode === 'full-page') return plan;

  const expandedRegions = await page.evaluate((indices) => {
    const regions = [...document.querySelectorAll('[data-sgr-scroll-container]')];
    return indices.map((index) => {
      const element = regions[index];
      if (!element) throw new Error(`Missing scroll region ${index} during review capture`);
      const width = element.scrollWidth;
      element.style.setProperty('width', `${width}px`, 'important');
      element.style.setProperty('max-width', 'none', 'important');
      element.style.setProperty('overflow', 'visible', 'important');
      return { index, width };
    });
  }, plan.wide_region_indices);
  return { ...plan, expanded_regions: expandedRegions };
}

async function capture(browser, side, sourcePath, theme, destination, viewport) {
  const consoleErrors = [];
  const pageErrors = [];
  const externalResourceErrors = [];
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: viewport.device_scale_factor,
    colorScheme: theme,
    locale: 'en-US', timezoneId: 'UTC', reducedMotion: 'reduce'
  });
  const fontBundle = side === 'upstream' ? loadFontAssets(root) : null;
  const fontRequests = fontBundle ? await installFontRoutes(context, fontBundle) : [];
  const page = await context.newPage();
  page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()); });
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (isExternal(request.url())) externalResourceErrors.push({ url: request.url(), error: request.failure()?.errorText || 'unknown' });
  });
  await page.goto(pathToFileURL(sourcePath).href, { waitUntil: 'load' });
  const fontEvidence = fontBundle
    ? await assertIntendedFonts(page, fontBundle)
    : await page.evaluate(async () => {
      if (document.fonts) await document.fonts.ready;
      return document.fonts ? { status: document.fonts.status, faces: [...document.fonts].map((face) => ({ family: face.family, status: face.status })) } : null;
    });
  if (externalResourceErrors.length > 0) {
    throw new Error(`${side} capture has external resource failures: ${JSON.stringify(externalResourceErrors)}`);
  }
  await page.waitForTimeout(100);
  const evidence = await inspect(page);
  evidence.fonts = fontEvidence;
  const screenshot = path.join(destination, `${side}.png`);
  const review_capture = await prepareReviewScreenshot(page, side, evidence);
  await page.screenshot({ path: screenshot, fullPage: true });
  await context.close();
  return {
    source: path.relative(root, sourcePath), screenshot: path.relative(root, screenshot), theme,
    console_errors: consoleErrors, page_errors: pageErrors, external_resource_errors: externalResourceErrors,
    font_requests: fontRequests, review_capture, ...evidence
  };
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const outcomes = [];
  try {
    for (const item of batch.cases) {
      const record = records.get(item.baseline_case_id);
      if (!record) throw new Error(`No pinned V0 record for ${item.baseline_case_id}`);
      const fixture = fixtures.get(item.local_fixture);
      if (!fixture) throw new Error(`${item.baseline_case_id}: unknown local fixture ${item.local_fixture}`);
      const variant = fixture.variants[item.local_variant];
      if (!variant) throw new Error(`${item.baseline_case_id}: ${item.local_fixture} has no ${item.local_variant} variant`);
      if (!['captured', 'unavailable'].includes(variant.status)) throw new Error(`${item.baseline_case_id}: unsupported local variant status ${variant.status}`);
      if (item.local_render !== variant.status) throw new Error(`${item.baseline_case_id}: batch local_render ${item.local_render} disagrees with configured ${variant.status} variant`);
      if (record.local_render.variant !== item.local_variant) throw new Error(`${item.baseline_case_id}: batch local variant ${item.local_variant} disagrees with pinned ${record.local_render.variant}`);
      const destination = path.join(outputRoot, item.baseline_case_id.replace(':', '__'));
      fs.mkdirSync(destination, { recursive: true });
      const assetPath = path.join(root, record.upstream_asset.local_path);
      const digest = require('crypto').createHash('sha256').update(fs.readFileSync(assetPath)).digest('hex');
      if (digest !== record.upstream_asset.sha256) throw new Error(`${item.baseline_case_id}: pinned upstream SHA-256 mismatch`);
      const contractPath = path.join(root, record.upstream_contract.local_path);
      const contractDigest = require('crypto').createHash('sha256').update(fs.readFileSync(contractPath)).digest('hex');
      if (contractDigest !== record.upstream_contract.sha256) throw new Error(`${item.baseline_case_id}: pinned upstream contract SHA-256 mismatch`);
      const theme = record.local_render.theme;
      const upstream = await capture(browser, 'upstream', assetPath, theme, destination, batch.viewport);
      let local = { status: variant.status, reason: variant.reason || null };
      if (variant.status === 'captured') {
        const localPath = path.join(generatedRoot, `${item.baseline_case_id.replace(':', '__')}.html`);
        if (!fs.existsSync(localPath)) throw new Error(`${item.baseline_case_id}: expected generated local fixture ${localPath}`);
        local = { status: 'captured', ...await capture(browser, 'slimgraphr', localPath, theme, destination, batch.viewport) };
      }
      const result = {
        schema_version: 1,
        baseline_case_id: item.baseline_case_id,
        classification: record.audit.classification,
        review_status: 'pending-human-visual-review',
        upstream: { sha256: digest, expected_sha256: record.upstream_asset.sha256, ...upstream },
        local,
        contract: { ...record.upstream_contract, sha256: contractDigest, expected_sha256: record.upstream_contract.sha256 },
        note: 'Capture evidence is not a visual-parity promotion.'
      };
      fs.writeFileSync(path.join(destination, 'evidence.json'), `${JSON.stringify(result, null, 2)}\n`);
      fs.writeFileSync(path.join(destination, 'review.html'), reviewPage(result));
      outcomes.push(result);
    }
  } finally {
    await browser.close();
  }
  fs.writeFileSync(path.join(outputRoot, 'summary.json'), `${JSON.stringify({ batch: batch.name, outcomes }, null, 2)}\n`);
  console.log(`captured ${outcomes.length} parity cases in ${path.relative(root, outputRoot)}`);
})().catch((error) => { console.error(`parity capture failed: ${error.stack || error.message}`); process.exit(1); });
