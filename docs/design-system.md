---
name: Scholarly Precision
colors:
  surface: '#f8f9ff'
  surface-dim: '#d0dbed'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dee9fc'
  surface-container-highest: '#d9e3f6'
  on-surface: '#121c2a'
  on-surface-variant: '#43474e'
  inverse-surface: '#27313f'
  inverse-on-surface: '#eaf1ff'
  outline: '#74777f'
  outline-variant: '#c4c6cf'
  surface-tint: '#476083'
  primary: '#000613'
  on-primary: '#ffffff'
  primary-container: '#001f3f'
  on-primary-container: '#6f88ad'
  inverse-primary: '#afc8f0'
  secondary: '#b22738'
  on-secondary: '#ffffff'
  secondary-container: '#fe5f6b'
  on-secondary-container: '#640014'
  tertiary: '#040607'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c1f21'
  on-tertiary-container: '#848688'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#afc8f0'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#2f486a'
  secondary-fixed: '#ffdad9'
  secondary-fixed-dim: '#ffb3b3'
  on-secondary-fixed: '#40000a'
  on-secondary-fixed-variant: '#900723'
  tertiary-fixed: '#e1e2e4'
  tertiary-fixed-dim: '#c5c6c8'
  on-tertiary-fixed: '#191c1e'
  on-tertiary-fixed-variant: '#444749'
  background: '#f8f9ff'
  on-background: '#121c2a'
  surface-variant: '#d9e3f6'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  body-lg:
    fontFamily: Source Serif 4
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Source Serif 4
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  caption:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
  container-max: 1280px
---

## Brand & Style

The brand personality is academic, disciplined, and authoritative. It targets high-achievers, researchers, and professionals who value the ritual of deep work and structured time management. The UI evokes the feeling of a high-end physical planner—specifically the "Harvard-style" layout—prioritizing clarity, intellectual focus, and a sense of calm productivity.

The design style is **Minimalist with a High-Contrast/Modern edge**. It utilizes a "Neo-Academic" aesthetic: heavy whitespace, precise alignment, and a sophisticated hierarchy that treats interface elements with the same care as a published manuscript. The emotional response is one of reliability and quiet confidence, removing digital clutter to allow the user’s schedule to take center stage.

## Colors

The palette is rooted in a traditional academic spectrum. 
- **Primary (Deep Navy):** Used for navigation, primary actions, and key headers to establish authority and focus.
- **Secondary (Crimson Accent):** Reserved for delicate highlights, such as the current "Now" indicator in the timebox or critical alerts, referencing classic editorial marking.
- **Neutral/Background:** A foundation of crisp white (`#FFFFFF`) and soft grays (`#F9FAFB`) provides a high-contrast canvas that mimics premium paper stock. 
- **Typography:** Deep charcoal is used instead of pure black to maintain a sophisticated, ink-on-paper feel.

## Typography

This design system uses a dual-font approach to balance modernity with tradition. 
- **Hanken Grotesk** is used for headlines, navigation, and labels. Its sharp, contemporary geometry provides the "professional/SaaS" clarity required for a digital tool.
- **Source Serif 4** is utilized for body text and notes. As a highly legible, academic-leaning serif, it reinforces the "timebox planner" metaphor and aids in long-form reading of task descriptions.
- **Hierarchy:** All-caps labels with slight letter spacing are used for metadata and section headers to mimic the look of an indexed journal.

## Layout & Spacing

The layout follows a **Fixed Grid** philosophy on desktop to maintain the look of a structured page, and a **Fluid Grid** on mobile for functional density.
- **Vertical Rhythm:** A strict 4px baseline grid ensures that the time increments in the timebox (15m, 30m, 60m blocks) align perfectly with the typography.
- **Margins:** Generous outer margins (64px on desktop) create a "letterhead" feel, focusing the user's eye on the central schedule.
- **Desktop:** 12-column grid with a fixed maximum width to prevent task rows from becoming too wide to read comfortably.
- **Mobile:** 4-column grid with reduced margins to maximize the horizontal space for task labels.

## Elevation & Depth

To maintain the minimalist academic aesthetic, depth is created through **Tonal Layers** and **Low-Contrast Outlines** rather than heavy shadows.
- **Surfaces:** The main canvas is pure white. Secondary panels (like a sidebar or inspector) use a subtle gray (`#F3F4F6`) to appear physically behind the main content.
- **Borders:** Elements are defined by thin, 1px borders in a soft light-gray (`#E5E7EB`).
- **Shadows:** When an element is "picked up" (e.g., dragging a timebox), use a single, ultra-diffused ambient shadow: `0 10px 30px rgba(0, 31, 63, 0.05)`. The hint of navy in the shadow tint keeps the depth cohesive with the brand palette.

## Shapes

The shape language is **Soft (0.25rem)**. This slight rounding takes the "edge" off the interface to make it feel premium and modern, while maintaining the structural integrity of a grid-based planner. 
- Buttons and input fields use the standard `0.25rem` radius.
- Cards containing specific "Timeblocks" use `0.5rem` (`rounded-lg`) to distinguish them from the background grid lines.
- No pill-shaped elements are used, as they feel too "social media" and conflict with the scholarly narrative.

## Components

- **Timeblocks:** The core component. Features a thin left-border in the Primary Navy or Category color, a white background, and a subtle 1px border.
- **Buttons:**
    - *Primary:* Solid Deep Navy with white text. No gradients.
    - *Secondary:* Ghost style with a thin navy border and navy text.
- **Input Fields:** Minimalist design with only a bottom border that thickens and changes to Primary Navy on focus, mimicking a lined notebook.
- **Checkboxes:** Square with sharp corners (0px radius) to reflect "checking off" a list in a manual.
- **Lists:** High-density, separated by light 1px dividers.
- **Empty States:** Use centered, serif typography (Source Serif 4) and ample whitespace to suggest "a clean slate" for the day's planning.
