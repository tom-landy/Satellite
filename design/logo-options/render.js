// Renders the ten candidates as a contact sheet beside Orbit. node design/logo-options/render.js
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const marks = require('./marks.js');
let n = 0;
const uniq = (svg) => { n += 1; return svg.replaceAll('-ID', '-' + n).replaceAll('id="fg"', `id="fg${n}"`).replaceAll('url(#fg)', `url(#fg${n})`).replaceAll('id="bg"', `id="bg${n}"`).replaceAll('url(#bg)', `url(#bg${n})`).replaceAll('id="glow"', `id="glow${n}"`).replaceAll('url(#glow)', `url(#glow${n})`); };
const tile = (inner, top = '#9CCBFF', bottom = '#2F6BF0') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#23262D"/><stop offset="1" stop-color="#0C0D10"/></linearGradient>
  <linearGradient id="fg" gradientUnits="userSpaceOnUse" x1="0" y1="216" x2="0" y2="808"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="${bottom}" stop-opacity="0.22"/><stop offset="1" stop-color="${bottom}" stop-opacity="0"/></radialGradient></defs>
  <rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#glow)"/>${inner}</svg>`;
const orbit = fs.readFileSync('/home/user/tom-landy/warhound_1.0/design/logo-template.svg', 'utf8').replaceAll('{{TOP}}', '#FFB25C').replaceAll('{{BOTTOM}}', '#F2551D');
const cell = (svg, n, name, note) => `<div class="cell"><div class="big">${uniq(svg)}</div>
  <div class="row"><div class="small">${uniq(svg)}</div><div class="small dim">${uniq(svg)}</div></div>
  <div class="name"><b>${n}</b> ${name}</div><div class="note">${note}</div></div>`;
const html = `<!doctype html><html><head><style>
  body{margin:0;padding:28px;background:#f2f2f7;font:15px -apple-system,system-ui,Helvetica,sans-serif;color:#1c1c1e}
  h1{font-size:20px;margin:0 0 18px}
  .grid{display:grid;grid-template-columns:repeat(4,250px);gap:26px}
  .cell svg{display:block;width:100%;height:100%}
  .big{width:200px;height:200px;border-radius:45px;overflow:hidden;box-shadow:0 6px 18px rgba(0,0,0,.18)}
  .row{display:flex;gap:10px;margin:12px 0 8px}
  .small{width:60px;height:60px;border-radius:14px;overflow:hidden}
  .small.dim{width:40px;height:40px;border-radius:9px;align-self:flex-end}
  .name{font-size:15px}.note{color:#6c6c70;font-size:13px;line-height:1.35;margin-top:2px;width:230px}
  .ref .big{outline:3px solid #F26A2A;outline-offset:4px}
</style></head><body><h1>Satellite mark options (blue), beside Orbit</h1><div class="grid">
${cell(orbit, '', 'Orbit (for reference)', 'The existing family mark.').replace('class="cell"', 'class="cell ref"')}
${marks.map((m, i) => cell(tile(m.svg), i + 1, m.name, m.note)).join('\n')}
</div></body></html>`;
fs.writeFileSync(path.join(__dirname, 'options.html'), html);
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1180, height: 800 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.join(__dirname, 'options.html'));
  await p.screenshot({ path: path.join(__dirname, 'options.png'), fullPage: true }); await b.close();
})();
