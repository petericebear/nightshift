---
description: Generate on-brand ad creatives (Google Ads, LinkedIn single + carousel, Meta/IG) from a title + description, using brand assets in .context/brand-assets.
argument-hint: "\"<title>\" \"<description>\" [platforms: google,linkedin,carousel,meta]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
model: fable
---

# Nightshift — ad creatives

Generate a set of platform-exact, on-brand advertising images.

Input: **$ARGUMENTS**
- First quoted string = **title/offer**, second = **description**. Optional trailing list
  narrows platforms (`google`, `linkedin`, `carousel`, `meta`); default = all.
- If no title/description is given, infer the offer from `.context/SPEC.md` / `PRD.md` /
  README and confirm the angle briefly.

Steps:
1. Ensure `.context/brand-assets/` exists (scaffold from
   `${CLAUDE_PLUGIN_ROOT}/assets/brand-assets-template/` if missing; tell the user to add
   their logo + edit `DESIGN.md`). Brand colors/fonts/logo/guardrails come from there.
2. Hand off to the **ad-designer** subagent to: write copy, generate base visuals via
   `scripts/adgen.sh` (Codex/gpt-image-2), composite crisp text + logo per format via
   `scripts/compose.py`, QA every image visually, and write a manifest.
3. Output goes to `.context/ad-creatives/<slug>/` with an `index.md` listing each asset
   (platform, size, and the exact headline/subhead/CTA used).

Formats & sizes come from `${CLAUDE_PLUGIN_ROOT}/assets/ad_specs.json`
(Google 1200×628 / 1200×1200 / 900×1200; LinkedIn 1200×628 / 1200×1200; LinkedIn
carousel 1080×1080 ×N; Meta 1080×1080 / 1080×1920).

Backends: image generation defaults to Codex (`NIGHTSHIFT_IMAGE_BACKEND=api` +
`OPENAI_API_KEY` for a direct-API fallback). Requires `pillow` for compositing
(`pip install pillow`). If the image backend is unavailable, still produce drafts using
the brand-gradient fallback and say so.
