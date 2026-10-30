# Pre-game UI redesign

This update gives the title hub, Play mode gallery, hero browser, character selection, custom/LAN lobbies, lobby browser, profile and build-notes screens a shared Overwatch-inspired visual hierarchy. The existing character artwork stays in use. A new original arena courtyard backdrop, original SVG mode symbols, pale form panels, bold navigation, selected portrait borders and orange primary actions provide the visual system.

## Behavior preserved

Existing mode-selection and launch handlers, online matchmaking/cancel actions, custom lobby operations, LAN validation, account-name validation, bot slot selection and host readiness checks remain wired. The LAN 2v2 roster is separate from host-only preset and vision controls. EOS keeps 2v2 disabled under the existing restriction. Hero cards support keyboard accept, visible focus, selected and locked states; hover no longer accumulates scale. Character descriptions are shared between the hero browser and selection screen.

No new matchmaking service, gameplay rules or character kits are introduced. The companion HUD changes are described in hud-feedback.md. Screens are authored for the project's existing 1920x1080 logical viewport and rendered at 1280x720 window size through its viewport stretch setting.

## Button backgrounds and navigation follow-up (2026-10-29)

Home has one PLAY entry, which opens the mode gallery. Selecting a card stays in that gallery and marks exactly one mode selected. The orange action states its effect: FIND MATCH, CHOOSE HEROES, START TUTORIAL, OPEN LOBBY or OPEN LAN. This replaces the ambiguous Home launch button and the mode-selection round trip through Home.

Home navigation gains a white plate with dark lettering on hover, keyboard focus and press. The gallery uses tall pale lavender illustrated cards, stacked secondary cards, blue selected/hover backgrounds with white/cyan borders, and muted disabled controls. Primary actions retain orange normal/pressed backgrounds. Native Godot theme StyleBoxes and a small mode-card script implement these states; the cards reuse existing hero illustrations and the original SVG symbols. No additional raster assets were generated for this follow-up.

Visual reference: [Overwatch Play menu screenshot](https://media.esports.gg/uploads/2024/11/image-3-65.jpg), published with [Quick Play Hacked: Limit 2](https://esports.gg/news/overwatch/overwatch-2-quick-play-hacked-limit-2-now-live/). This is an adaptation of the visible hierarchy and button states using Hex-Arena artwork. The earlier REA artifact inspection did not recover Overwatch's native widget layouts or button implementation.

The updated pre-game regression and rendered fixture run reported PREGAME_SCREENS_COMPLETE failures=0 with no GDScript errors. It checks the single Home entry, all five explicit action labels, and exactly one selected mode, alongside the existing pre-game checks. The local Godot shutdown problem described below remains unresolved.

## Generated asset details

Follow-up: game-mode cards now use large mode symbols on plain themed backgrounds. Character illustrations and their gradient overlays have been removed from these buttons; Home and hero selection still use the existing character artwork. This change adds no assets.

Built-in image_gen tool used (no API/CLI fallback). The generated image was copied into the project at assets/ui/backgrounds/arena_courtyard.png. It is included in the full binary patch, not loaded from an external URL or Codex's image cache. Original generated output remains unchanged. PNG SHA-256: 114100ded1bf3a4e9a2338894b2ebc35fa729a6f9d1802e386adfc45cdd9831f.

Final prompt:

> Use case: stylized-concept. Asset type: production background plate for a fantasy arena game's pre-game menus, no interface baked into the image. Create a very wide 16:9 landscape illustration of a tranquil futuristic fantasy training courtyard: pale limestone terraces and warm sandstone, subtle hexagonal floor inlays, sculptural arches and a central distant circular combat platform, high airy blue-gray sky, a few teal glass architectural accents, warm late-afternoon sun, polished painterly 3D game concept-art aesthetic. Broad simple values, atmospheric depth and soft details, elegant and inviting. Composition: left third is low-detail cool shaded wall / atmosphere reserved for large white navigation text, right third has a softly lit open terrace to sit behind an existing character illustration, middle has distant architecture. Muted blue-gray / ivory palette with small warm amber light accents. Camera eye-level, no dramatic tilt. No people, no characters, no lettering, no logos, no watermarks, no UI frames, no controls, no emblems associated with existing games. This is an original environment for Hex Arena, not a screenshot of another game. Deliver a single seamless clean background image.

## Verification

After importing assets in Godot:

    godot --headless --path . tests/pregame_screens.tscn
    godot --headless --path . tests/hud_feedback.tscn
    godot --headless --path . tests/playtest_smoke.tscn

To capture the pre-game fixtures with a rendering-capable engine:

    godot --path . tests/pregame_screens.tscn -- --screenshots=/absolute/writable/folder

The screen test covers navigation, mode choice, selected hero, empty lobby headers, busy/cancel controls, invalid LAN and profile inputs, bot selection, keyboard selection, locked heroes, hover stability and four-player readiness. It does not contact matchmaking services, create a live lobby, save a profile or launch a match. Rendered fixtures were inspected; LAN-toggle overflow and lobby-list contrast issues found in the first pass were fixed.

Local Godot 4.7.2 results on 2026-10-28: PREGAME_SCREENS_COMPLETE failures=0, HUD_FEEDBACK_COMPLETE failures=0, PLAYTEST_SMOKE_COMPLETE failures=0, with no GDScript errors in final runs. This does not mean clean process exits: all three final runs returned Windows 0xC0000374 after completion. Cause remains unresolved. The environment also reports certificate-store/telemetry access issues and graphics shader-cache errors. Verify on the branch-targeted Godot 4.6 and manually test real LAN/EOS sessions before release.
