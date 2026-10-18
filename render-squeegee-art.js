// Renders squeegee-art.html frame by frame over a folder of background JPGs (bg_0001.jpg …).
// Usage: node render-squeegee-art.js <bg-dir> <out-dir> <frame-count>
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const [BG, OUT, N] = [process.argv[2], process.argv[3], parseInt(process.argv[4], 10)];
const FPS = 30;
const fileUrl = p => 'file:///' + path.resolve(p).split(path.sep).join('/');

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--allow-file-access-from-files'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
  await page.goto(fileUrl(path.join(__dirname, 'squeegee-art.html')), { waitUntil: 'networkidle0' });
  console.log('timeline', await page.evaluate(() => window.ready));
  for (let i = 0; i < N; i++) {
    const bg = fileUrl(path.join(BG, `bg_${String(i + 1).padStart(4, '0')}.jpg`));
    await page.evaluate((t, src) => window.renderAt(t, src), i / FPS, bg);
    await page.screenshot({ path: path.join(OUT, `f_${String(i + 1).padStart(4, '0')}.jpg`), type: 'jpeg', quality: 92 });
    if (i % 60 === 0) console.log('frame', i);
  }
  await browser.close();
})();
