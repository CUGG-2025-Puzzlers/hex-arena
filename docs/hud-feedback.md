# Overwatch-style HUD for Hex-Arena

This revision replaces the bottom-center dashboard with an Overwatch-inspired screen hierarchy: hero portrait and segmented health at bottom left, a circular resource gauge at bottom center, compact monochrome ability icons and keycaps at bottom right, and a top-center objective scoreboard. The gauge is explicitly labeled MANA and reflects current/max mana; it does not introduce an ultimate ability. Character art is Hex-Arena's existing portrait artwork. New glyphs are original SVGs.

## Evidence and design boundary

The REA skill was used, including an installed rea-agents 6.8.0 CLI with Node 24.22.1. No MCP/configuration changes or analysis-engine installation were made.

- REA desktop inspection parent Evidence ID: ev_a1a7b1f2053f823818bf8fe02cc1a7f80f262d7cce880c3bfb39bf79211bcf79. It examined 1,256 directory entries and probed 31 files / 10,524 bytes. This is a bounded directory/header inspection, not complete binary decoding or a runtime trace.
- REA PE import Evidence ID: ev_bab8e30264c4547795228066e251a756a5062b16a3eec7f91d5be169c1013672. The browser helper declares 56 CEF imports. This establishes a static dependency, not execution or how the native HUD widgets render.
- Blizzard's annotated 2019 viewing guide, PDF page 15 (zero-based page 14), documents separate hero-health, ability/ammo, ultimate, and objective regions: https://bnetcmsus-a.akamaihd.net/cms/gallery/FFZU579I3MZW1551477224855.pdf#page=15 . This is the classic visual reference, not proof of the exact HUD shipped in the installed 2.25 build.
- Earlier byte inspection found openModal/closeModal and scene keyboard/mouse interfaces. The modal ownership fix remains in this update.

REA's native decompilation engines are not configured on this machine. Native widget code and CASC UI layouts were not recovered. Layout, typography, segmented drawing and mana adaptation are Hex-Arena implementation choices. This must not be described as extracted Overwatch HUD source or a pixel-exact reconstruction.

## Implementation

Godot CanvasLayer/Control nodes own presentation. Existing resource and cooldown signals feed the widgets. Health segments and the mana ring draw through small native Godot controls. Root-relative anchors separate the screen regions under the project's 1920x1080 viewport. The existing match model supplies team percentages, round-win dots, point ownership, capture and overtime; scoring rules are unchanged.

Decorative HUD controls pass pointer input to the arena. The concede dialog explicitly blocks local MultiplayerInput while visible and releases ownership on close, rebind or teardown. Other peers continue. Magic cards mark low base-cost mana without promising valid placement, wire length or targeting.

## Verification

After importing assets:

    godot --headless --path . tests/hud_feedback.tscn
    godot --headless --path . tests/playtest_smoke.tscn

For a rendered fixture:

    godot --path . tests/hud_feedback.tscn -- --screenshot=/absolute/path/hud.png --hud-ready-preview

Omit --hud-ready-preview for critical-health / low-mana feedback. The objective header in the fixture uses explicit test values; it is not a real multiplayer session.

Local Godot 4.7.2 runs on 2026-10-28 reported HUD_FEEDBACK_COMPLETE failures=0 and PLAYTEST_SMOKE_COMPLETE failures=0 with no GDScript errors. The HUD tests also cover the mana fraction, portrait, split layout, cooldown reset, silence/death priority, modal input, rebinding, freeing and overtime's 99% display. Rendered previews were inspected.

The engine still does not exit cleanly: the final headless HUD run returned Windows 0xC0000374 after completion. Cause remains unresolved; the repository documents an EOS native shutdown issue on Linux, but that does not prove the cause here. Certificate-store and editor-settings access were restricted; OpenGL rendering logged shader initialization errors. Godot 4.6 verification and a real LAN playtest remain outstanding.
