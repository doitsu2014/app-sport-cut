# Sportcut brand mark

The Sportcut mark is a court in perspective with one court-green play signal
sitting on the net. It follows the studio design system: a low-glare stage
surface, chalk court geometry, and a single accent reserved for action.

| Token | Value | Use |
| --- | --- | --- |
| Surface | `#121814` | Icon tile |
| Hairline | `#2B342E` | Tile edge |
| Chalk | `#F2F5F0` | Court geometry |
| Signal | `#46D08D` | Play triangle |
| Shadow | 28 % black, 12 px down / 18 px blur | Icon lift |

## Files

| File | Use |
| --- | --- |
| `sportcut-icon.svg` | 128–1024 px app icon: full court, centre line, shadow |
| `sportcut-icon-small.svg` | 16–64 px app icon: no centre line, no shadow, larger court, heavier strokes |

The macOS app icon set is generated from these sources:

```bash
tools/generate-app-icons.sh
# writes app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png
```

The generated PNGs are committed; a normal build does not need the script.

## Rules

- Court geometry stays chalk. The play signal is the only green element.
- Do not add gradients, glows, celebratory effects, or a second accent.
- Keep the tile's corner radius proportional to the canvas; the icon is not a
  square-cornered tile.
- The mark may sit on the stage surface without the tile when a dark surface
  already provides it. Do not place the dark tile on a dark, unbroken field
  without the hairline edge.
- The wordmark is `Sportcut` in Archivo semibold, tracking `-0.01em`, set beside
  the 26 px mark at header sizes.
