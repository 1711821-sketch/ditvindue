const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const OUT = process.argv[2];
const IDS = ['hook', 'pro', 'streg', 'reveal', 'name', 'end', 'se'];
const CLIPPED = { before: [1080, 1350], after: [1080, 1350], bar: [1080, 90] };

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
  const base = 'file:///' + path.join(__dirname, 'video-overlays.html').split(path.sep).join('/');
  for (const id of IDS) {
    await page.goto(`${base}?id=${id}`, { waitUntil: 'networkidle0' });
    await page.evaluateHandle('document.fonts.ready');
    await page.screenshot({ path: path.join(OUT, `ov_${id}.png`), omitBackground: true });
    console.log('rendered', id);
  }
  for (const [id, [w, h]] of Object.entries(CLIPPED)) {
    await page.goto(`${base}?id=${id}`, { waitUntil: 'networkidle0' });
    await page.evaluateHandle('document.fonts.ready');
    await page.screenshot({ path: path.join(OUT, `ov_${id}.png`), omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } });
    console.log('rendered', id);
  }
  await browser.close();
})();
