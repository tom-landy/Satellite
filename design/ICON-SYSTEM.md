# Warhound icon system

The rules Orbit and Satellite share. Give this file to anyone (or any LLM) making a mark for
another Warhound app.

## The brief

Make an app icon on a 1024×1024 canvas, as SVG, following these rules exactly.

**Tile**
- Full-bleed square. No rounded corners or outer padding: iOS applies the mask itself.
- Background: vertical linear gradient from `#23262D` (top) to `#0C0D10` (bottom).
- Glow: a radial gradient over the background, centred, radius 512, starting with the theme's
  bottom colour at 22% opacity and fading to 0% at the edge.

**Mark**
- One simple, geometric symbol. No text, no letters, no outlines around the whole mark.
- Footprint: the mark's outer edges stay inside x 216–808 and y 216–808 (a 592 px box, 58% of the
  tile, with 216 px of clear space on every side). Centre it at (512, 512). It doesn't have to fill
  the whole box; Satellite's dish covers 531 px of it.
- Main stroke: 92 px, round caps and joins. Secondary strokes (arms, struts): 44 px.
  Dots: radius 58 for a small one, radius 74 for a main or centre one.
- Fill every part with the theme gradient: vertical linear, `gradientUnits="userSpaceOnUse"`,
  from y 216 (theme top colour) to y 808 (theme bottom colour). One gradient for the whole mark,
  with no second colour.
- Shapes are built from circles, arcs and straight lines on Orbit's grid where possible:
  centre (512, 512), ring radius 250.
- It must still read at 40 px. If a detail vanishes at that size, remove it.

**Themes**
Ten colour themes, each a (top, bottom) gradient pair. The app picks one as its default. The other
nine are alternate icons that are identical apart from colour.

| Theme | Top | Bottom | Base (UI accent on dark) | UI accent on light |
|---|---|---|---|---|
| orange | `#FFB25C` | `#F2551D` | `#F26A2A` | `#CD4800` |
| ember | `#FF8A6B` | `#D92D2D` | `#EC4A3C` | `#DA372C` |
| gold | `#FFE08A` | `#EE9F1A` | `#F5B83D` | `#A26800` |
| lime | `#D4F27A` | `#5DB82E` | `#8FD14F` | `#468300` |
| mint | `#8FF5C8` | `#1FAF7A` | `#3DD39A` | `#008653` |
| teal | `#86ECF0` | `#1497B0` | `#2CC2D4` | `#008091` |
| blue | `#9CCBFF` | `#2F6BF0` | `#4D8DFF` | `#3270E0` |
| violet | `#D3B5FF` | `#7A4AF0` | `#A57DFF` | `#845AD9` |
| pink | `#FFA8CB` | `#EE3D82` | `#FF6AA5` | `#CD3B7B` |
| silver | `#FFFFFF` | `#9EA2AD` | `#D4D7DE` | `#71747A` |

Defaults so far: Orbit is orange, Satellite is blue. Give each new app a different default, so the
apps are easy to tell apart on the Home Screen.

**Output**
- An SVG template that uses `{{TOP}}` and `{{BOTTOM}}` placeholders for the theme colours.
- 1024×1024 PNGs per theme, without transparency (RGB), rendered from the template.
  `design/render-icons.js` in Orbit or Satellite does this with Playwright.
- The same geometry drawn natively in the app (SwiftUI `LogoView`), so in-app logos follow the theme.

## Reference geometry

Orbit (a ring with a gap, a satellite in the gap, and a core):

```svg
<path d="M 559.7 266.6 A 250 250 0 1 0 757.4 464.3" fill="none" stroke="url(#fg)" stroke-width="92" stroke-linecap="round"/>
<circle cx="689" cy="335" r="58" fill="url(#fg)"/>
<circle cx="512" cy="512" r="74" fill="url(#fg)" opacity="0.9"/>
```

Satellite (the half of Orbit's ring opposite the gap, used as a dish, with the feed where Orbit's
satellite sits):

```svg
<path d="M 688.8 688.8 A 250 250 0 0 1 335.2 335.2" fill="none" stroke="url(#fg)" stroke-width="92" stroke-linecap="round"/>
<path d="M 512 512 L 650.6 373.4" fill="none" stroke="url(#fg)" stroke-width="44" stroke-linecap="round"/>
<circle cx="689" cy="335" r="58" fill="url(#fg)"/>
```

The full template, with the tile and gradients, is in `design/logo-template.svg`.
