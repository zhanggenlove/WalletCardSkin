---
name: Liquid Sequoia Canvas
colors:
  surface: '#fcf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fcf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#414755'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#005ab3'
  on-secondary: '#ffffff'
  secondary-container: '#0073e0'
  on-secondary-container: '#fefcff'
  tertiary: '#006b25'
  on-tertiary: '#ffffff'
  tertiary-container: '#008730'
  on-tertiary-container: '#f7fff2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#d6e3ff'
  secondary-fixed-dim: '#aac7ff'
  on-secondary-fixed: '#001b3e'
  on-secondary-fixed-variant: '#00468d'
  tertiary-fixed: '#6cff82'
  tertiary-fixed-dim: '#47e266'
  on-tertiary-fixed: '#002106'
  on-tertiary-fixed-variant: '#00531a'
  background: '#fcf8fb'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0.01em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

This design system expresses the native precision, tactile lightness, and fluid clarity of modern macOS Sequoia desktop applications. Built around digital craftsmanship and personalization, the design mirrors Apple's premium Human Interface Guidelines while introducing an intentional gallery-grade preview stage for Apple Wallet passes.

The aesthetic blends **Glassmorphism** and **macOS Modernism**:
- **Frosted Materials:** Translucent chrome, vibrant materials, and layered optical depths (`backdrop-filter: blur(24px)` to `blur(48px)`).
- **Physical Feedback:** Micro-highlights across outer borders that simulate diamond-cut anodized aluminum edges and continuous glass refraction.
- **Restraint & Vibrancy:** A neutral, quiet container architecture designed to recede completely, letting vivid digital card art, gradients, and metallic card finishes take center stage.
- **Desktop Ergonomics:** Uncompromising adherence to native window dynamics—integrated unified titlebars, authentic window control traffic lights, pill-shaped contextual status capsules, and floating bottom command bars.

## Colors

The palette is engineered around Apple's System Blue for interaction affordance and System Green for live device sync indicators, all anchored on light, translucent macOS neutral tones.

### System Palette
- **Primary (`#007AFF`):** The signature Apple action color used for primary CTAs (e.g., "应用到 iPhone"), active segmented indicators, and focused card border strokes.
- **Secondary (`#0A84FF`):** Vibrant system tint applied to hover interactions and fluid card gradients.
- **Tertiary (`#30D158`):** Device connection pulse, indicating active AirDrop/Nearby wireless pairing state.
- **Neutral Foreground (`#1D1D1F`):** Deep SF text ink with exceptional clarity.

### Functional Glass Surfaces
- **Window Base Canvas:** `#F8F9FA` with subtle desktop luminance pass-through.
- **Card Preview Stage:** Solid-to-subtle radial wash `#FFFFFF` over `#F2F4F7`.
- **System Chrome Material:** `rgba(255, 255, 255, 0.72)` with a 30px backdrop blur and `rgba(255, 255, 255, 0.4)` top-edge specular highlight.
- **Subtle Surface Stroke:** `rgba(0, 0, 0, 0.06)` on light containers; `rgba(255, 255, 255, 0.65)` inner bevel rim for glass components.

## Typography

The typography leverages **Plus Jakarta Sans** as an open, contemporary companion to Apple's native San Francisco design language, capturing clean geometric proportions and soft grotesque humanist touches.

- **Window Title & Navigation:** Set in `headline-sm` with tight kerning (`-0.01em`) and medium-to-bold weights to maintain immediate legibility across macOS titlebars.
- **Card Metadata & Tags:** Handled by `label-md` and `label-sm`, rendering at high contrast for card names, secondary subtitle descriptions, and device indicators.
- **Numeric & Wallet Data:** Numerals inherit tabular alignment with uniform vertical metrics to prevent baseline jitter during real-time card updates.

## Layout & Spacing

Layout adheres to an 8pt modular grid structured to fit native macOS window proportions (ideal default ratio: `1180px × 820px`).

### Structure
1. **Unified Header / Titlebar (48px height):** Houses native window controls (12px dots with 8px gap) pinned left, centered or inline app branding, and accessory status capsules pinned right with `margin: 1.5rem`.
2. **Interactive Stage Carousel (280px to 320px vertical zone):** Card gallery centered with full optical clearance. Cards dynamically scale and tilt on swipe/hover. Floating circular pagination chevrons flank the stage at `1.5rem` from window edges.
3. **Skin Selection Grid:** 5-column fluid CSS grid using `gutter: 1rem`. Cards adapt to min-width `180px` and scale proportionally.
4. **Floating Action Deck (44px height):** Fixed `1.5rem` above the bottom window rim, centered horizontally with `0.5rem` element spacing between pill commands.

## Elevation & Depth

Visual depth is achieved through translucent material layering rather than pure drop shadows:

- **Level 0 (App Canvas):** Translucent base with macOS system desktop blur: `background: rgba(255, 255, 255, 0.85); backdrop-filter: blur(40px) saturate(180%)`.
- **Level 1 (Card Skin Tiles & Containers):** Layered inset cards with thin hairline border:
  - Border: `1px solid rgba(0, 0, 0, 0.08)`.
  - Box Shadow: `0 1px 3px rgba(0, 0, 0, 0.04), 0 4px 12px rgba(0, 0, 0, 0.03)`.
  - Hover: `0 6px 20px rgba(0, 0, 0, 0.08), 0 1px 4px rgba(0, 0, 0, 0.04)`.
- **Level 2 (Active Stage Wallet Pass):** Raised physical card elevation mimicking Apple Wallet physics:
  - Shadow: `0 20px 48px -12px rgba(0, 122, 255, 0.28), 0 8px 24px -4px rgba(0, 0, 0, 0.12)`.
  - Inner Rim: `inset 0 1px 1px 0 rgba(255, 255, 255, 0.4)`.
- **Level 3 (Floating Toolbars & Overlays):** Liquid glass pills:
  - Background: `rgba(255, 255, 255, 0.88)`.
  - Border: `1px solid rgba(0, 0, 0, 0.06)`.
  - Shadow: `0 8px 32px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.04)`.

## Shapes

The interface embraces Apple's continuous curve aesthetics (squircle geometry):

- **Window Canvas:** `rounded-xl` (1.5rem / 24px) continuous corner radius with native window drop shadow clipping.
- **Wallet Passes:** Strict `rounded-lg` (1rem / 16px) matching Apple Wallet card geometry (`3.370 × 2.125` aspect ratio).
- **Skin Grid Tiles:** `rounded-lg` (0.75rem to 1rem / 14px) with inner thumbnail clipping maintaining uniform 1px perimeter inset.
- **Pills & Floating Action Buttons:** Full pill geometry (`rounded-full` / 9999px) used for macOS utility chips, status indicators, and button groups.

## Components

### Buttons & Command Floating Bar
- **Primary Pill (`应用到 iPhone`):** Solid `#007AFF` fill, pure white text, inline SF-style download icon. On hover: `#0062CC`, scaled 1.02× with continuous cubic-bezier transition (`transform: scale(1.02); transition: all 180ms ease-out`).
- **Secondary Pill (`导入图片`, `重新扫描`):** Background `rgba(0, 0, 0, 0.05)`, text `#1D1D1F`, hover background `rgba(0, 0, 0, 0.09)`.
- **Icon Chevrons:** 32px circular buttons with translucent white background `rgba(255, 255, 255, 0.9)`, hairline border, holding 12px chevron icons.

### Skin Selector Card Tiles
- Consists of two sections: top color/image canvas (60% card height) and bottom label area (40% card height).
- **Selected State:** Border transitions to `2px solid #007AFF` accompanied by an outer halo `0 0 0 3px rgba(0, 122, 255, 0.25)`.
- **Label Display:** Top row displays title in `label-lg` (`#1D1D1F`), subtext below in `label-sm` (`#86868B`).

### Status Capsule (Connected Device)
- Floating capsule at the top right: `height: 28px`, padding `0 12px`, background `rgba(0, 0, 0, 0.04)`.
- Features an animated or fixed tertiary green status dot (`#30D158`, 6px × 6px) indicating connected iPhone device state.

### Pagination Indicators
- Centered underneath the preview stage: 6px height pills. The inactive pill is `6px × 6px` circle with `rgba(0, 0, 0, 0.2)`; the active pill expands to `16px × 6px` capsule filled with `#007AFF`.