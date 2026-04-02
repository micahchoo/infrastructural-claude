# Visual Design Thinking

A framework for translating vague aesthetic intent into concrete frontend decisions. Use this when choosing colors, shadows, spacing, typography character, or overall visual direction — any time a design decision feels subjective.

Adapted from professional visual direction methodology. Source: MeiGen AI Design MCP prompt engineering system (MIT).

## The Core Problem

Vague intent produces generic output. "Make it modern" yields the same gray-and-blue SaaS template every time. The fix: decompose aesthetic intent into four concrete dimensions before writing any CSS.

## The Decomposition Method

When a user describes a desired feel — or when you need to choose a visual direction — apply these four dimensions:

### 1. Technical Precision over Feeling

Translate vibes into concrete design properties. Never stop at adjectives.

| Vague intent | Decomposed into properties |
|---|---|
| "premium" | Dark surfaces, generous whitespace (32-48px sections), restrained 2-color palette, subtle gradients (2-3% opacity), serif or thin geometric headings, minimal borders |
| "friendly" | Warm palette (amber/coral accents), rounded corners (12-16px), soft shadows (large blur, low opacity), medium-weight sans-serif, generous line-height (1.6+) |
| "professional" | Neutral palette with single accent, tight spacing scale, strong typographic hierarchy (3+ distinct sizes), minimal decoration, high contrast text |
| "bold/editorial" | High contrast, oversized type (clamp 3-6rem headings), asymmetric whitespace, one dramatic accent color, tight letter-spacing on headings |
| "clean" | Monochromatic or analogous palette, consistent spacing unit (8px base), thin borders or none, ample padding, system or geometric sans-serif |
| "playful" | Saturated palette (3+ colors), rounded shapes, bouncy transitions (spring easing), informal type (rounded sans-serif or hand-drawn), varied visual weight |
| "luxurious" | Deep backgrounds (#0a0a0a range), gold/champagne accents, extra letter-spacing (0.05-0.1em), thin weight fonts, subtle texture (noise overlay at 2-3% opacity) |
| "technical" | Monospace or tabular type, dense layout, muted palette with cyan/green accents, sharp corners, thin 1px borders, small base font (14px) |

### 2. Spatial Logic

Define the spatial system explicitly before placing elements.

- **Spacing scale**: Pick a base unit (4px or 8px) and use consistent multiples. Don't mix arbitrary values.
- **Density**: Sparse (product/marketing: 48-64px between sections) vs. dense (dashboards/tools: 8-16px between elements). Match the content type.
- **Hierarchy layers**: Typically 3 — page (margins/max-width), section (vertical rhythm), component (internal padding). Define each.
- **Visual weight distribution**: Where does the eye land first? Size, color, and whitespace create hierarchy — not just font-weight.

### 3. Material and Surface

How do surfaces behave? This drives shadow, border, and background decisions.

- **Elevation model**: Define 2-4 levels. Each level has a shadow treatment. Use consistent light direction across all shadows.
  - Level 0: Flat (no shadow, or inset treatment)
  - Level 1: Resting (subtle shadow — `0 1px 3px rgba(0,0,0,0.08)`)
  - Level 2: Raised (interactive/hover — `0 4px 12px rgba(0,0,0,0.12)`)
  - Level 3: Floating (modals/dropdowns — `0 12px 32px rgba(0,0,0,0.16)`)
- **Surface texture**: Glass (backdrop-blur + semi-transparent bg), paper (subtle noise + warm tones), metal (linear gradients + sharp highlights), fabric (matte colors + no shine)
- **Border philosophy**: None (rely on whitespace), hairline (1px at 0.1 opacity), visible (semantic — dividers between content), heavy (decorative — accent-colored)
- **Interaction feedback**: How surfaces respond — color shift, shadow elevation change, scale transform, border-color transition. Pick one or two, not all.

### 4. Cohesive Rationale

Every visual choice should trace back to a single design intent. If you can't explain why a shadow is 12px blur instead of 8px, the choice is arbitrary.

Write a one-sentence design rationale before generating CSS:
> "This interface should feel like a well-lit gallery — generous whitespace, minimal chrome, content as the focal point, with subtle shadows suggesting physical depth."

Then test every decision against it. Gallery feel means: no heavy borders (they frame too aggressively), large images (content is art), restrained type palette (don't compete with content), warm neutral background (gallery walls, not screens).

## Style Archetypes

Three reference styles with concrete CSS implications. Use as starting points, not templates.

### Clean / Corporate
- **Palette**: 1 primary accent + neutrals (slate/gray). High contrast text (7:1+ ratio).
- **Type**: Geometric sans-serif headings (DM Sans, Outfit, Plus Jakarta Sans), humanist body text. Tight heading letter-spacing (-0.02em).
- **Spacing**: 8px base. Consistent, predictable rhythm.
- **Shadows**: Minimal. 1-2 elevation levels. Low blur, low opacity.
- **Corners**: Subtle (6-8px) or none. Never > 12px.
- **Signals**: Restraint. Precision. Nothing unnecessary.

### Bold / Editorial
- **Palette**: High contrast. Dark bg + light text OR white bg + near-black text. One dramatic accent.
- **Type**: Display serif or heavy sans for headings (clamp(2rem, 5vw, 4rem)). Strong size contrast between heading and body (3:1+ ratio). Negative letter-spacing on large text (-0.03em).
- **Spacing**: Asymmetric. Generous vertical space, tight horizontal grouping. Whitespace is intentional, not default.
- **Shadows**: Rarely used. Depth via layering and overlap instead.
- **Corners**: Sharp (0-4px). Rounded corners undermine the editorial feel.
- **Signals**: Confidence. Intentionality. Every element earns its space.

### Warm / Organic
- **Palette**: Earth tones or muted pastels. Warm neutrals (cream, sand, warm gray). Accent from complementary warmth (terracotta, sage, dusty rose).
- **Type**: Rounded sans-serif or humanist (Nunito, Quicksand, Karla). Generous line-height (1.65-1.75). Relaxed letter-spacing.
- **Spacing**: Generous padding inside components. Breathing room. 12px+ base gaps.
- **Shadows**: Soft, diffused. Large blur radius (16-24px), very low opacity (0.06-0.1). Warm shadow color (not pure black — use `rgba(30, 20, 10, 0.08)`).
- **Corners**: Rounded (12-16px). Pill shapes for buttons/tags. Soft edges throughout.
- **Signals**: Approachability. Comfort. Handmade quality.

## Multi-Direction Exploration

When visual direction isn't specified, don't default to "clean SaaS." Instead, propose 2-3 distinct directions with concrete tokens for each:

```
Direction A: "Observatory" — dark mode, monospace accents, cyan highlights, dense layout
Direction B: "Atelier" — warm cream bg, serif headings, terracotta accent, generous space
Direction C: "Newsroom" — high contrast, bold sans, editorial layout, sharp corners
```

Each direction should include: background color, text color, accent color, heading font suggestion, corner radius, and shadow approach. Enough for the user to visualize the difference without a mockup.

## Anti-Patterns

- **The Gray Void**: `#f5f5f5` background, `#333` text, blue links, no personality. Default to a warmer neutral or a tinted background.
- **Shadow Soup**: Mixing shadow directions, blur sizes, and opacities without a system. Pick an elevation scale and stick to it.
- **Corner Roulette**: 4px here, 12px there, 24px on that card. Use 2-3 corner radius values max, with a clear rule for each (small for inputs, medium for cards, large for modals).
- **Font Stack Anxiety**: Using 3+ font families. Two is almost always enough (heading + body). Mono is a third only for code-heavy UIs.
- **Spacing by Eye**: Random padding/margin values. Every space should be a multiple of your base unit.
- **Decoration as Design**: Gradients, patterns, and ornaments added to fill visual emptiness. If the layout feels empty, fix the spacing and typography — don't add decoration.
