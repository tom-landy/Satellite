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
- Size (the Warhound sizing brief, matched to the Binary icon): the mark's widest extent,
  including stroke caps and dots, is 74% of the canvas (758 px), leaving a 13% (133 px) margin.
  Centre the mark's bounding box on the canvas, within ±1.5% (15 px).
- Strokes: 103 px (10%), round caps and joins, for every arc and line. Small dots about 125–130 px
  across (12%), large dots about 176 px (17%).
- Get there by scaling the geometry about the centre, then setting strokes and dots to those
  sizes. Don't scale the whole mark uniformly, which makes strokes too heavy.
- Fill every part with the theme gradient: vertical linear, `gradientUnits="userSpaceOnUse"`,
  running from the mark's top edge (theme top colour) to its bottom edge (theme bottom colour).
  One gradient for the whole mark, with no second colour.
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
- An SVG template that uses `{{TOP}}` and `{{BOTTOM}}` placeholders for the theme colours, with the
  background in `<g id="tile">` so it can be dropped for the dark and tinted versions.
- Per theme, three 1024×1024 PNGs: default (RGB, no transparency), dark (the mark on transparency)
  and tinted (the mark in white to light grey, on transparency). `design/render-icons.js` in
  Satellite renders all three and writes the asset catalog entries.
- Check each default and dark PNG with `tools/measure_icon.py`: every line must read OK.
- The same geometry drawn natively in the app (SwiftUI `LogoView`), so in-app logos follow the theme.

## Reference geometry

These are the shapes at their original size, before the sizing brief. Satellite's resized geometry is
in its `design/logo-template.svg`.

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
