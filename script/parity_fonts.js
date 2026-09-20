'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const FONT_CSS_URL = 'https://fonts.googleapis.com/css2';
const LOCAL_FONT_HOST = 'https://fonts.slimgraphr.invalid/';

function readManifest(root) {
  const manifestPath = path.join(root, 'script', 'parity-fonts.json');
  try {
    return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    throw new Error(`Parity font manifest is unreadable: ${error.message}`);
  }
}

function loadFontAssets(root, manifest = readManifest(root)) {
  if (manifest.schema !== 'slim_graph_r/parity-fonts-v1' || !Array.isArray(manifest.faces)) {
    throw new Error('Parity font manifest has an unsupported schema or no faces');
  }
  const assets = manifest.faces.map((face) => {
    const absolutePath = path.resolve(root, face.path || '');
    if (!absolutePath.startsWith(`${root}${path.sep}`) || !fs.existsSync(absolutePath)) {
      throw new Error(`Required parity font is missing: ${face.path}`);
    }
    const body = fs.readFileSync(absolutePath);
    const sha256 = crypto.createHash('sha256').update(body).digest('hex');
    if (sha256 !== face.sha256) {
      throw new Error(`Required parity font SHA-256 mismatch for ${face.path}: expected ${face.sha256}, got ${sha256}`);
    }
    return { ...face, absolutePath, body, sha256 };
  });
  return { manifest, assets };
}

function fontCss(assets) {
  return assets.map((face, index) => `@font-face{font-family:${JSON.stringify(face.family)};font-style:${face.style};font-weight:${face.weight};font-display:block;src:url(${LOCAL_FONT_HOST}${index}) format("woff2");}`).join('\n');
}

async function installFontRoutes(context, fontBundle) {
  const served = [];
  await context.route(`${FONT_CSS_URL}*`, async (route) => {
    served.push({ url: route.request().url(), kind: 'stylesheet', source: 'local-intercept' });
    await route.fulfill({ contentType: 'text/css; charset=utf-8', body: fontCss(fontBundle.assets) });
  });
  await context.route(`${LOCAL_FONT_HOST}**`, async (route) => {
    const index = Number(new URL(route.request().url()).pathname.slice(1));
    const asset = fontBundle.assets[index];
    if (!asset) return route.abort('failed');
    served.push({ url: route.request().url(), kind: 'font', source: 'local-intercept', path: asset.path, sha256: asset.sha256 });
    await route.fulfill({ contentType: 'font/woff2', body: asset.body, headers: { 'access-control-allow-origin': '*' } });
  });
  return served;
}

async function assertIntendedFonts(page, fontBundle) {
  const required = fontBundle.assets.map((face) => ({ family: face.family, style: face.style, weight: face.weight }));
  const observed = await page.evaluate(async (faces) => {
    const specs = faces.map((face) => `${face.style} ${face.weight.split(' ')[0]} 16px "${face.family}"`);
    await Promise.all(specs.map((spec) => document.fonts.load(spec, 'Parity typography probe')));
    await document.fonts.ready;
    return {
      status: document.fonts.status,
      checks: specs.map((spec, index) => ({ ...faces[index], spec, loaded: document.fonts.check(spec, 'Parity typography probe') })),
      faces: [...document.fonts].map((face) => ({ family: face.family, style: face.style, weight: face.weight, status: face.status }))
    };
  }, required);
  const missing = observed.checks.filter((face) => !face.loaded);
  if (observed.status !== 'loaded' || missing.length > 0) {
    throw new Error(`Intended parity fonts did not load: ${JSON.stringify({ status: observed.status, missing })}`);
  }
  return { source: 'local-intercept', assets: fontBundle.assets.map(({ body, absolutePath, ...face }) => face), ...observed };
}

function isExternal(url) {
  return /^https?:\/\//i.test(url) && !url.startsWith(LOCAL_FONT_HOST);
}

module.exports = { assertIntendedFonts, installFontRoutes, isExternal, loadFontAssets, readManifest };
