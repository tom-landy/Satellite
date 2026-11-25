// Contact sheet for the dish variations: node design/logo-options/render-dish.js
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const { marks, colours } = require('./dish.js');
let n = 0;
const tile = (inner, fg2 = ['#9CCBFF', '#2F6BF0'], top = '#9CCBFF', bottom = '#2F6BF0') => {
  n += 1;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#23262D"/><stop offset="1" stop-color="#0C0D10"/></linearGradient>
  <linearGradient id="fg" gradientUnits="userSpaceOnUse" x1="0" y1="216" x2="0" y2="808"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>
  <linearGradient id="fg2" gradientUnits="userSpaceOnUse" x1="0" y1="277" x2="0" y2="393"><stop offset="0" stop-color="${fg2[0]}"/><stop offset="1" stop-color="${fg2[1]}"/></linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="${bottom}" stop-opacity="0.22"/><stop offset="1" stop-color="${bottom}" stop-opacity="0"/></radialGradient></defs>
  <rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#glow)"/>${inner}</svg>`;
  return svg.replaceAll('-ID', '-' + n).replace(/id="(bg|fg2|fg|glow)"/g, `id="$1${n}"`).replace(/url\(#(bg|fg2|fg|glow)\)/g, `url(#$1${n})`);
};
const orbit = () => { n += 1; return fs.readFileSync('/home/user/tom-landy/warhound_1.0/design/logo-template.svg', 'utf8')
  .replaceAll('{{TOP}}', '#FFB25C').replaceAll('{{BOTTOM}}', '#F2551D').replace(/id="(bg|fg|glow)"/g, `id="$1o${n}"`).replace(/url\(#(bg|fg|glow)\)/g, `url(#$1o${n})`); };
const cell = (make, label, note, cls = '') => `<div class="cell ${cls}"><div class="big">${make()}</div>
  <div class="row"><div class="small">${make()}</div><div class="small dim">${make()}</div></div>
  <div class="name">${label}</div><div class="note">${note}</div></div>`;
const themes = [['#FFB25C', '#F2551D'], ['#86ECF0', '#1497B0'], ['#D3B5FF', '#7A4AF0'], ['#D4F27A', '#5DB82E'], ['#FFFFFF', '#9EA2AD']];
const html = `<!doctype html><html><head><style>
  body{margin:0;padding:28px;background:#f2f2f7;font:15px -apple-system,system-ui,Helvetica,sans-serif;color:#1c1c1e}
  h1{font-size:20px;margin:0 0 18px} h2{font-size:17px;margin:34px 0 16px}
  .grid{display:grid;grid-template-columns:repeat(5,220px);gap:24px}
  .cell svg{display:block;width:100%;height:100%}
  .big{width:180px;height:180px;border-radius:40px;overflow:hidden;box-shadow:0 6px 18px rgba(0,0,0,.18)}
  .row{display:flex;gap:10px;margin:12px 0 8px}
  .small{width:60px;height:60px;border-radius:14px;overflow:hidden}
  .small.dim{width:40px;height:40px;border-radius:9px;align-self:flex-end}
  .name{font-size:15px;font-weight:600}.note{color:#6c6c70;font-size:13px;line-height:1.35;margin-top:2px;width:205px}
  .ref .big{outline:3px solid #F26A2A;outline-offset:4px}
  .themes{display:flex;gap:14px}.themes .big{width:120px;height:120px;border-radius:27px}
</style></head><body>
<h1>Dish variations (blue), beside Orbit</h1><div class="grid">
${cell(orbit, 'Orbit', 'For reference: the satellite at upper right.', 'ref')}
${marks.map((m, i) => cell(() => tile(m.svg), `${String.fromCharCode(65 + i)}. ${m.name}`, m.note)).join('\n')}
</div>
<h2>Does the dot get its own colour? (on B, Orbit dish)</h2><div class="grid">
${colours.map((c, i) => cell(() => tile(c.svg, c.fg2), `${i + 1}. ${c.name}`, c.note)).join('\n')}
</div>
<h2>B, Orbit dish, in other themes</h2><div class="themes">
${themes.map(t => `<div class="big">${tile(marks[1].svg, t, t[0], t[1])}</div>`).join('')}
</div>
</body></html>`;
fs.writeFileSync(path.join(__dirname, 'dish.html'), html);
(async () => {
  const b = await chromium.launch(); const pg = await b.newPage({ viewport: { width: 1270, height: 800 } });
  await pg.goto('file://' + path.join(__dirname, 'dish.html'));
  await pg.screenshot({ path: path.join(__dirname, 'dish.png'), fullPage: true }); await b.close();
})();
