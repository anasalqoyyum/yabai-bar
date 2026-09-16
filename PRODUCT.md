# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

The shipped product is a native macOS utility. The `adaptive` value records that it follows the host Mac's light and dark appearances rather than imposing its own theme.

## Stack

Inferred from the handoff specification: Swift 6-compatible source, AppKit for the menu-bar surface, SwiftUI for Settings, and Swift Package Manager for reproducible app, helper, and test builds. The minimum deployment target is macOS 13 because launch-at-login uses `SMAppService`.

## Users

People who already use yabai and often skhd to manage macOS spaces. They need to see workspace state and switch spaces with the mouse without installing a replacement menu bar.

## Product purpose

Yabai Bar observes yabai spaces, displays them in the native macOS menu bar, and focuses a selected space through yabai. Success means the displayed state stays current through yabai events, clicks do not steal focus, and failures remain diagnosable without changing the user's yabai or macOS security setup.

## Positioning

One native status item presents the entire workspace group. Yabai remains responsible for window management and skhd remains responsible for keyboard control.

## Operating context

The app runs as an accessory process beside yabai. A bundled command-line helper delivers yabai signal events to a Unix-domain socket. The app reads `~/.config/yabai-bar/config.json` and can register itself as a login item.

## Capabilities and constraints

- Support yabai 7.1.19 or newer.
- Query and focus spaces through argument-based `Process` calls.
- Preserve empty spaces by default and distinguish focused from visible spaces.
- Reconcile only signals carrying the `yabai-bar.` label prefix.
- Avoid workspace polling while healthy. A low-frequency timer may check connectivity and signal registration.
- Do not request Accessibility, Screen Recording, or Input Monitoring permission.
- Do not manage windows, hotkeys, space creation, SIP, or the yabai scripting addition.
- Release signing, notarization, and Homebrew cask publication require downstream credentials and distribution setup.

## Evidence on hand

The source of truth is [yabai-bar-v1-spec.md](yabai-bar-v1-spec.md). No logo, screenshots, existing application code, testimonials, or distribution credentials were supplied.

## Product principles

- Stay inside the native menu bar.
- Treat yabai as the authority for workspace state and focus capability.
- Make repeated focus requests silent and harmless.
- Recover from process, display, and sleep changes without an app restart.
- Keep configuration and appearance intentionally small.

## Accessibility & inclusion

Use native controls in Settings, expose clear workspace accessibility labels, respect system appearance, and provide non-color cues for focused and visible states.
