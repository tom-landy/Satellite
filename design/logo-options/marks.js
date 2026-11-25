// Ten candidate Satellite marks on Orbit's 1024 grid: dark tile, theme gradient, stroke 92,
// round caps, roughly Orbit's bounding box (216 to 808). Gaps where shapes cross are real
// cut-outs (masks), so the tile shows through. "url(#fg)" is the theme gradient; "ID" is
// replaced per icon so several can share a page. Rendered by render.js.
const S = 92;
const st = (w = S) => `fill="none" stroke="url(#fg)" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"`;
const cut = (w) => `fill="none" stroke="black" stroke-width="${w}" stroke-linecap="round"`;
const p = (cx, cy, r, deg) => [cx + r * Math.cos(deg * Math.PI / 180), cy + r * Math.sin(deg * Math.PI / 180)].map(n => +n.toFixed(1));
const mask = (id, black) => `<mask id="${id}-ID" maskUnits="userSpaceOnUse" x="-1024" y="-1024" width="3072" height="3072"><rect x="-1024" y="-1024" width="3072" height="3072" fill="white"/>${black}</mask>`;

const tilted = (() => {
  const [sx, sy] = [+(340 * Math.cos(Math.PI / 5)).toFixed(1), +(132 * Math.sin(Math.PI / 5)).toFixed(1)];
  const back = 'M -340 0 A 340 132 0 0 1 340 0', front = 'M -340 0 A 340 132 0 0 0 340 0';
  return `<g transform="rotate(-28 512 512) translate(512 512)">
    ${mask('tb', '<circle r="140" fill="black"/>')}
    ${mask('tc', `<path d="${front}" ${cut(110)}/>`)}
    ${mask('tf', `<circle cx="${sx}" cy="${sy}" r="82" fill="black"/>`)}
    <path d="${back}" ${st(64)} mask="url(#tb-ID)"/>
    <circle r="112" fill="url(#fg)" mask="url(#tc-ID)"/>
    <path d="${front}" ${st(64)} mask="url(#tf-ID)"/>
    <circle cx="${sx}" cy="${sy}" r="58" fill="url(#fg)"/></g>`;
})();

module.exports = [
  { id: 'sputnik', name: 'Sputnik', note: 'The first satellite: a sphere trailing antennae.', svg: `
    ${mask('sp', '<circle cx="610" cy="410" r="176" fill="black"/>')}
    <g ${st(40)} mask="url(#sp-ID)"><path d="M 600 430 L 340 790"/><path d="M 600 430 L 250 700"/><path d="M 600 430 L 215 585"/></g>
    <circle cx="610" cy="410" r="150" fill="url(#fg)"/>` },

  { id: 'panels', name: 'Solar panels', note: 'The satellite everyone draws: body and two panel wings.', svg: `
    <g transform="rotate(-35 512 512)" fill="url(#fg)">
      <rect x="432" y="432" width="160" height="160" rx="36"/>
      <rect x="300" y="496" width="140" height="32" rx="16"/><rect x="584" y="496" width="140" height="32" rx="16"/>
      <rect x="168" y="352" width="138" height="146" rx="22"/><rect x="168" y="526" width="138" height="146" rx="22"/>
      <rect x="718" y="352" width="138" height="146" rx="22"/><rect x="718" y="526" width="138" height="146" rx="22"/>
    </g>` },

  { id: 'tilted', name: 'Tilted orbit', note: "Orbit's ring tipped into 3D, a satellite riding the front.", svg: tilted },

  { id: 'horizon', name: 'Horizon', note: "The planet's edge, and a satellite climbing over it.", svg: `
    <path d="M ${p(300, 1010, 520, -150)} A 520 520 0 0 1 ${p(300, 1010, 520, -10)}" ${st()}/>
    <path d="M ${p(300, 1010, 700, -122)} A 700 700 0 0 1 ${p(300, 1010, 700, -62)}" ${st(30)} stroke-dasharray="1 62"/>
    <circle cx="${p(300, 1010, 700, -50)[0]}" cy="${p(300, 1010, 700, -50)[1]}" r="70" fill="url(#fg)"/>` },

  { id: 'page-orbit', name: 'Page in orbit', note: 'An article with a satellite circling it.', svg: (() => {
    const arc = 'M -330 40 A 330 120 0 0 0 330 40';
    return `<g transform="rotate(-20 512 512) translate(512 512)">${mask('po', `<path d="${arc}" ${cut(96)}/><circle cx="330" cy="40" r="80" fill="black"/>`)}</g>
    <g mask="url(#po-ID)">
      <rect x="352" y="282" width="320" height="420" rx="56" ${st(64)}/>
      <g ${st(44)}><path d="M 436 400 H 588"/><path d="M 436 490 H 588"/><path d="M 436 580 H 530"/></g>
    </g>
    <g transform="rotate(-20 512 512) translate(512 512)">
      ${mask('pa', '<circle cx="330" cy="40" r="80" fill="black"/>')}
      <path d="${arc}" ${st(40)} mask="url(#pa-ID)"/>
      <circle cx="330" cy="40" r="56" fill="url(#fg)"/>
    </g>`;
  })() },

  { id: 'dish', name: 'Dish', note: 'Receiving: a dish catching what the satellites send.', svg: `
    <path d="M ${p(470, 560, 270, 45)} A 270 270 0 0 1 ${p(470, 560, 270, 225)}" ${st()}/>
    <path d="M 470 560 L 650 380" ${st(44)}/>
    <circle cx="676" cy="354" r="64" fill="url(#fg)"/>` },

  { id: 's-orbit', name: 'S orbit', note: 'Two half-orbits make an S, with a satellite at each end.', svg: `
    <path d="M ${p(512, 382, 130, -60)} A 130 130 0 1 0 512 512 A 130 130 0 1 1 ${p(512, 642, 130, 120)}" ${st(80)}/>
    <circle cx="${p(512, 382, 130, 12)[0]}" cy="${p(512, 382, 130, 12)[1]}" r="50" fill="url(#fg)"/>
    <circle cx="${p(512, 642, 130, 192)[0]}" cy="${p(512, 642, 130, 192)[1]}" r="50" fill="url(#fg)"/>` },

  { id: 'crescent', name: 'Crescent', note: 'A moon and the small satellite sharing its sky.', svg: `
    ${mask('mo', '<circle cx="600" cy="430" r="250" fill="black"/>')}
    <circle cx="470" cy="560" r="270" fill="url(#fg)" mask="url(#mo-ID)"/>
    <circle cx="700" cy="330" r="62" fill="url(#fg)"/>` },

  { id: 'ringed', name: 'Ringed planet', note: 'A planet with a tight ring passing in front.', svg: (() => {
    const back = 'M -360 0 A 360 110 0 0 1 360 0', front = 'M -360 0 A 360 110 0 0 0 360 0';
    return `<g transform="rotate(-22 512 512) translate(512 512)">
      ${mask('rb', '<circle r="216" fill="black"/>')}
      ${mask('rp', `<path d="${front}" ${cut(104)}/>`)}
      <path d="${back}" ${st(56)} mask="url(#rb-ID)"/>
      <circle r="190" fill="url(#fg)" mask="url(#rp-ID)"/>
      <path d="${front}" ${st(56)}/></g>`;
  })() },

  { id: 'page-sat', name: 'Page satellite', note: 'A satellite whose body is a page of text.', svg: `
    <g transform="rotate(-35 512 512)">
      ${mask('ps', `<g ${cut(30)}><path d="M 452 450 H 572"/><path d="M 452 512 H 572"/><path d="M 452 574 H 530"/></g>`)}
      <rect x="402" y="372" width="220" height="280" rx="40" fill="url(#fg)" mask="url(#ps-ID)"/>
      <g fill="url(#fg)">
        <rect x="290" y="496" width="120" height="32" rx="16"/><rect x="614" y="496" width="120" height="32" rx="16"/>
        <rect x="170" y="392" width="128" height="240" rx="24"/><rect x="726" y="392" width="128" height="240" rx="24"/>
      </g>
    </g>` },
];
