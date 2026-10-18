const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const OUT = process.argv[2];
const CHAPTERS = [
  ['01', 'Skum på'],
  ['02', 'Træk af'],
  ['03', 'Slowmo'],
  ['04', 'Kant til kant'],
  ['05', 'Gentag'],
  ['06', 'Dino'],
];
const JOBS = [
  { name: 'title', q: 'id=title' },
  { name: 'titletext', q: 'id=titletext', transparent: true },
  { name: 'end', q: 'id=end' },
  { name: 'callout', q: 'id=callout', transparent: true },
  { name: 'split', q: 'id=split', transparent: true, clip: [1080, 1350] },
  ...CHAPTERS.map(([n, t]) => ({ name: `chrome_${n}`, q: `id=chrome&n=${n}&t=${encodeURIComponent(t)}`, transparent: true })),
];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
  const base = 'file:///' + path.join(__dirname, 'video-cards.html').split(path.sep).join('/');
  for (const j of JOBS) {
    await page.goto(`${base}?${j.q}`, { waitUntil: 'networkidle0' });
    await page.evaluateHandle('document.fonts.ready');
    const opts = { path: path.join(OUT, `card_${j.name}.png`), omitBackground: !!j.transparent };
    if (j.clip) opts.clip = { x: 0, y: 0, width: j.clip[0], height: j.clip[1] };
    await page.screenshot(opts);
    console.log('rendered', j.name);
  }
  await browser.close();
})();
