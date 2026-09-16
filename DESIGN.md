---
name: Yabai Bar
description: A compact, native workspace strip for the macOS menu bar.
colors:
  label: "CanvasText"
  selected: "Highlight"
  selected-label: "HighlightText"
  disabled-label: "GrayText"
  icon-background: "#232c40"
  icon-mark: "#f7f8fb"
typography:
  workspace:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "normal"
  workspace-active:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "normal"
  workspace-mono:
    fontFamily: "ui-monospace, SFMono-Regular, monospace"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "normal"
rounded:
  workspace: "6px"
spacing:
  compact: "4px"
  regular: "7px"
  relaxed: "10px"
components:
  workspace:
    textColor: "{colors.label}"
    typography: "{typography.workspace}"
    rounded: "{rounded.workspace}"
    padding: "3px 11px"
  workspace-focused:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.selected-label}"
    typography: "{typography.workspace}"
    rounded: "{rounded.workspace}"
    padding: "3px 11px"
  workspace-disabled:
    textColor: "{colors.disabled-label}"
    typography: "{typography.workspace}"
    rounded: "{rounded.workspace}"
    padding: "3px 11px"
---

# Design System: Yabai Bar

## Overview

**Creative North Star: "The Native Workspace Strip"**

Yabai Bar should look like a compact macOS control that has always belonged in the menu bar. Its identity comes from precise state communication and restraint. System appearance, typography, controls, and accessibility behavior take priority over decorative branding.

The workspace strip is the signature component. Focus uses a filled rounded selection, non-focused occupancy uses a small dot below the label, visibility on another display uses a small dot above the label, and unavailable state uses muted text plus an exclamation mark. Settings remain a conventional native utility window.

**Key Characteristics:**

- One continuous status item containing all workspace targets.
- Semantic system colors that adapt to the current macOS appearance.
- Compact labels with explicit focused, visible, pressed, disabled, and unavailable states.
- Native SwiftUI forms and SF Symbols in Settings.

## Colors

The palette is wholly semantic. AppKit resolves label, selected-content, selected-menu-item-text, secondary-label, control-accent, and disabled-control-text colors for the active system appearance.

### Primary

- **System Selection:** The focused pill uses `selectedContentBackgroundColor`; its label uses `selectedMenuItemTextColor`.

### Neutral

- **System Label:** Normal workspace text uses `labelColor`.
- **System Secondary Label:** The visible-on-another-display dot and unavailable indicator use `secondaryLabelColor`.
- **System Disabled Label:** Disconnected workspace controls use `disabledControlTextColor`.

**The Semantic Color Rule.** Do not replace AppKit semantic colors with fixed light or dark values.

### App icon

The app icon uses a graphite-blue macOS squircle with a white lowercase `y`. The mark is made from two rounded strokes so it remains clear at 16 pixels. Keep the icon free of text, gradients, and extra symbols.

## Typography

**Display Font:** None. This utility has no display typography.
**Body Font:** macOS system font.
**Label/Mono Font:** macOS system font, with the system monospaced font as a user setting.

**Character:** Menu-bar text is compact and functional. Settings inherit the native SwiftUI type hierarchy.

### Hierarchy

- **Workspace label** (medium, 12px): Default menu-bar space text.
- **Active workspace label** (bold, 12px): Used only when the active-indicator setting is Bold.
- **Unavailable indicator** (semibold, 11px): Compact failure state when yabai is unavailable.

**The Native Type Rule.** Use system typography in the status item and Settings; monospace is an explicit workspace-label preference, not a general technical aesthetic.

## Layout

The full workspace group occupies one variable-length `NSStatusItem`. Each label is an independent button within that item. Internal horizontal spacing is configurable at 4, 7, or 10 points, with 7 points as the default, plus a fixed 4-point hit-area inset on each side. The final button trims that fixed trailing inset because macOS supplies the spacing between menu-bar items. Label text is capped at 96 points and truncates at the tail so a long yabai label cannot consume the menu bar.

Settings use a 540 by 390 point window with General, Appearance, and Diagnostics tabs. Native grouped forms determine field alignment and density.

**The One Item Rule.** All workspaces stay inside one status item; never add a second gear, settings, or per-workspace status item.

## Elevation & Depth

The menu-bar surface is flat. State uses system fills and text changes, not shadows. Settings use only the depth supplied by native macOS windows and controls.

## Shapes

The focused workspace and pressed overlay use gently rounded 6-point corners. Occupancy and visible-on-another-display cues use 3-point circular dots on opposite sides of the label. Underline style uses a 2-point rounded rule. Pills are reserved for the compact active workspace control.

## Components

### Workspace buttons

- **Shape:** A compact rectangular hit target with a 6-point focused pill.
- **Default:** System label text on the transparent menu-bar surface.
- **Focused:** System selected-content fill and selected menu-item text.
- **Visible elsewhere:** A small secondary-label dot above the label when the space is visible but not focused.
- **Occupied:** A small secondary-label dot below a non-focused label when yabai reports one or more windows in the space. Focused spaces omit the redundant dot.
- **Pressed / Focus:** A semantic label-color overlay is drawn above the selected pill; the native focus ring remains enabled.
- **Unavailable:** Buttons stop accepting focus commands and use the disabled-control text color when yabai is disconnected.
- **Capability-limited:** Buttons become inert without changing appearance when the current macOS and yabai combination cannot focus spaces.

### Status item

The status item owns workspace controls and the unavailable indicator as one movable group. Right-clicking any workspace or non-button area opens the app menu.

### Settings

Settings use native SwiftUI `TabView`, `Form`, `Picker`, `Toggle`, `TextField`, `LabeledContent`, and system-symbol labels. Save is the default action; Revert restores the last persisted configuration.

## Do's and Don'ts

### Do:

- **Do** preserve one compact status item for the full workspace group.
- **Do** use semantic AppKit colors and native controls so light, dark, contrast, and accessibility settings carry through.
- **Do** keep focus and visible-on-another-display states distinct without relying on color alone.
- **Do** bound user-authored labels and preserve each workspace's click target.

### Don't:

- **Don't** add another status item for Settings or diagnostics.
- **Don't** add shadows, gradients, glass effects, or a custom theme engine.
- **Don't** turn system or failure state into notifications or decorative animation.
- **Don't** use monospace outside the explicit workspace-font preference.
