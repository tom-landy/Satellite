// Renders the app icons from logo-template.svg: for each theme, the default icon plus the dark
// (transparent background) and tinted (greyscale, transparent) versions iOS 18 asks for.
// Usage (needs Playwright): node design/render-icons.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const dir = __dirname;
const out = path.join(dir, '..', 'Satellite', 'Assets.xcassets');
const themes = JSON.parse(fs.readFileSync(path.join(dir, 'themes.json'), 'utf8'));
const template = fs.readFileSync(path.join(dir, 'logo-template.svg'), 'utf8');
// Satellite's primary icon is blue (AccentTheme.standard); the rest are alternates.
const primary = 'blue';
const noTile = svg => svg.replace(/<g id="tile">[\s\S]*?<\/g>/, '');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  const shoot = async (svg, file, transparent) => {
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await page.screenshot({ path: file, omitBackground: transparent });
  };
  for (const t of themes) {
    const svg = template.replaceAll('{{TOP}}', t.top).replaceAll('{{BOTTOM}}', t.bottom);
    const name = t.id === primary ? 'AppIcon' : `AppIcon-${t.id}`;
    const set = path.join(out, `${name}.appiconset`);
    fs.mkdirSync(set, { recursive: true });
    await shoot(svg, path.join(set, `${name}.png`), false);
    // Dark: the mark on transparency; iOS supplies the dark background.
    await shoot(noTile(svg), path.join(set, `${name}-dark.png`), true);
    // Tinted: greyscale; iOS colours it by brightness.
    const grey = template.replaceAll('{{TOP}}', '#FFFFFF').replaceAll('{{BOTTOM}}', '#BDBDC2');
    await shoot(noTile(grey), path.join(set, `${name}-tinted.png`), true);
    const image = (file, value) => ({
      ...(value ? { appearances: [{ appearance: 'luminosity', value }] } : {}),
      filename: file, idiom: 'universal', platform: 'ios', size: '1024x1024',
    });
    fs.writeFileSync(path.join(set, 'Contents.json'), JSON.stringify({
      images: [image(`${name}.png`), image(`${name}-dark.png`, 'dark'), image(`${name}-tinted.png`, 'tinted')],
      info: { author: 'xcode', version: 1 },
    }, null, 2) + '\n');
    console.log(name);
  }
  await browser.close();
})();
