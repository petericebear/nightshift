# Brand & Design System

The ad generator reads this file to stay on-brand. Fill it in. Keep the machine-readable
values in sync with `design.json` (the compositor reads `design.json`; humans read this).

## Brand
- **Company**: <Your Company>
- **Product**: <Product name>
- **Tagline**: <short tagline>
- **Voice / tone**: <e.g. confident, technical, friendly — a few adjectives>

## Colors
| Role | Hex | Notes |
|------|-----|-------|
| Primary / brand | `#141428` | used for scrims & gradient backgrounds |
| Accent | `#3B82F6` | CTA buttons, badges, highlights |
| Text on dark | `#FFFFFF` | headline/subhead over imagery |
| Text on light | `#0B0B14` | when background is light |

## Typography
- **Headline font**: <font name> (path if custom, e.g. `.context/brand-assets/fonts/Inter-Bold.ttf`)
- **Body font**: <font name>
- If no custom font is provided, the compositor falls back to a clean system sans.

## Logo
- Place logo files in `logo/` (PNG with transparent background preferred).
- Primary: `logo/logo.png` · light-on-dark variant: `logo/logo-white.png`
- Keep clear space around the logo; the compositor scales it to ~20% of width.

## Imagery style
- **Do**: <e.g. abstract gradients, product screenshots, real people at work>
- **Don't**: <e.g. cheesy stock photos, clip-art, competitor colors>
- **Motifs**: <recurring visual ideas, shapes, textures>

## Messaging guardrails
- **Always**: <claims we can make, required disclaimers>
- **Never**: <forbidden claims, superlatives, competitor mentions>
- **Primary CTA**: <e.g. "Start free" / "Book a demo">
