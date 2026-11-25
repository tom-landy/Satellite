// Dish variations. Most are built on Orbit's own geometry: centre (512, 512), ring radius 250,
// satellite dot at (689, 335) r 58, which lies on the ring at -45 degrees. The dish is the half
// of Orbit's ring opposite the gap, and the feed sits where Orbit's satellite does.
// "url(#fg)" is the theme gradient, "url(#fg2)" a second colour for the dot.
const st = (w = 92) => `fill="none" stroke="url(#fg)" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"`;
const p = (cx, cy, r, deg) => [cx + r * Math.cos(deg * Math.PI / 180), cy + r * Math.sin(deg * Math.PI / 180)].map(n => +n.toFixed(1));
const arc = (cx, cy, r, from, to, w = 92) => `<path d="M ${p(cx, cy, r, from)} A ${r} ${r} 0 0 1 ${p(cx, cy, r, to)}" ${st(w)}/>`;
const mask = (id, black) => `<mask id="${id}-ID" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><rect width="1024" height="1024" fill="white"/>${black}</mask>`;

const half = arc(512, 512, 250, 45, 225);          // Orbit's ring, the half opposite the gap
const arm = `<path d="M 512 512 L ${p(512, 512, 196, -45)}" ${st(44)}/>`;
const dot = (fill = 'url(#fg)') => `<circle cx="689" cy="335" r="58" fill="${fill}"/>`;
const core = `<circle cx="512" cy="512" r="74" fill="url(#fg)" opacity="0.9"/>`;

const marks = [
  { id: 'd-orig', name: 'Dish (as before)', note: 'The one you picked, for comparison.', svg: `
    ${arc(470, 560, 270, 45, 225)}<path d="M 470 560 L 650 380" ${st(44)}/><circle cx="676" cy="354" r="64" fill="url(#fg)"/>` },

  { id: 'd-orbit', name: 'Orbit dish', note: "Half of Orbit's ring as the dish; the feed sits exactly where Orbit's satellite does.", svg: `
    ${half}${arm}${dot()}` },

  { id: 'd-core', name: 'Orbit dish + hub', note: "As above, with Orbit's centre dot kept as the dish's hub.", svg: `
    ${half}${arm}${core}${dot()}` },

  { id: 'd-noarm', name: 'Half orbit', note: "No arm: Orbit with half its ring gone, the satellite now facing a dish.", svg: `
    ${half}${core}${dot()}` },

  { id: 'd-struts', name: 'Struts', note: 'The feed held by two struts from the rim, like a real dish.', svg: `
    ${half}<path d="M ${p(512, 512, 250, 45)} L 689 335 L ${p(512, 512, 250, 225)}" ${st(36)}/>${dot()}` },

  { id: 'd-bowl', name: 'Bowl', note: 'A solid dish, seen slightly side-on, with the feed in Orbit\'s spot.', svg: `
    ${mask('bw', `<circle cx="${p(512, 512, 92, -45)[0]}" cy="${p(512, 512, 92, -45)[1]}" r="262" fill="black"/>`)}
    <circle cx="512" cy="512" r="270" fill="url(#fg)" mask="url(#bw-ID)"/>${arm}${dot()}` },

  { id: 'd-shallow', name: 'Shallow dish', note: 'A flatter 120° dish, closer to the real thing.', svg: `
    ${arc(512, 512, 250, 75, 195)}${arm}${dot()}` },

  { id: 'd-wave', name: 'Dish + signal', note: 'One incoming wave beyond the feed. Only one, so it never reads as the feed icon.', svg: `
    ${half}${arm}${dot()}${arc(512, 512, 372, -62, -28, 40)}` },

  { id: 'd-upright', name: 'Upright', note: 'The dish pointing straight up, symmetrical.', svg: `
    ${arc(512, 452, 250, 0, 180)}<path d="M 512 452 L 512 292" ${st(44)}/><circle cx="512" cy="252" r="58" fill="url(#fg)"/>` },
];

// The dot in a second colour, on the Orbit dish.
const colours = [
  { name: 'Same gradient', note: "How Orbit does it: one colour per theme.", svg: `${half}${arm}${dot()}` },
  { name: 'White dot', note: 'The satellite lit up; works on every theme.', fg2: ['#FFFFFF', '#D9E6FF'], svg: `${half}${arm}${dot('url(#fg2)')}` },
  { name: "Orbit's orange", note: "The satellite is Orbit: the two apps literally linked.", fg2: ['#FFB25C', '#F2551D'], svg: `${half}${arm}${dot('url(#fg2)')}` },
  { name: 'Light shade', note: "The theme's own lightest tone, a quieter accent.", fg2: ['#D7E9FF', '#9CCBFF'], svg: `${half}${arm}${dot('url(#fg2)')}` },
];

module.exports = { marks, colours };
