# Combat readability and feedback, second pass

Implemented directly in the existing gameplay-overhaul working copy. The accompanying patch is incremental from the exact working files before this pass; it is already applied. Do not apply it again. No commits, staging, or publishing were performed in the user checkout.

## Transformation previews

Every nearby registered spell shows three small action/result markers. Hover a spell for the destination names, mana costs, and blocked/insufficient-mana explanations. Check mark = predicted eligible; horizontal bar = insufficient mana; cross = blocked or no transform. Labels follow InputMap bindings (default Q Shield, E Light, R Heavy). Characters whose Passive action creates wires do not get a misleading Passive-transform preview.

The planner follows the server's radius conversion and self-cell-first/reverse-radius traversal. Each action gets its own simulated mana budget across the entire batch, including different per-spell costs. It respects ownership, unsupported transformations, visible hostile occupancy, and the self-cell shield restriction. It does not send commands, spend mana, or replace server validation. Preview hides during death, silence, blocked match phases, and UI modals.

Prediction remains advisory: replication latency and invisible occupants can change the server result. Hidden opponents deliberately do not contribute occupancy hints; preventing fog information leaks takes priority over perfect prediction. Placement and wire-link previews are outside this transform-specific pass.

## Prepared magic

One observer per arena samples at 20 Hz and renders at frame rate. It displays up to 64 nearby visible spell states, rechecking fog visibility at draw time. Broken circle = unclaimed; square = owned/prepared; filling arc = Pressure Lance charging; diamond = ready; half arc = Tideblade recovery; cross = exhausted; small dots = remaining Tideblade attacks. Expiring shields get a contracting lifetime arc based on their actual Timer, with an expiry accent. Existing authored sprites and team outlines remain in place.

## Useful actions and contact

Positive shield contact gets a local BLOCKED confirmation. Cutting a vulnerable hostile projectile with wire gets INTERCEPTED. Added root/silence duration gets distinct world glyphs and ROOTED/SILENCED feedback for the source player. Equal or shorter crowd-control reapplications cannot claim success. Success messages yield to elimination and objective notices and are debounced.

Wall, shield, player, and spell contacts have separate short visual/synthetic sound cues. Wall contact uses the last visible movement sample because the current wall collision helper returns a boolean, not an exact collision normal. It is not a recovered contact manifold. Existing player-hit feedback remains authoritative; no fixed screen-center hitmarker was added.

## Endings and movement

Explicit lifecycle call sites distinguish expiration (contracting ring), completion (small check), interruption (split cross), and visible homing-target loss (separated arcs). Shield Timer expiry, spent Pressure Lance/Burst, Hush Wave completion, Root Hand range expiry, Gentle Mote range/consumption, wire cuts, wall interruptions, teleport cancellation, and Ghost completion are wired. Unclassified generic cleanup and scene destruction stay quiet. Losing a homing target does not destroy the projectile or claim it missed; it can acquire another target. Remaining custom character lifecycles retain their existing authored feedback.

Dash/Reform, Flash, and completed Teleport get directional departure/arrival accents. Cancelled dashes get interruption instead of arrival. Ordinary movement start/stop has a small silent directional streak with a 250 ms gate. All effects are separate presentation nodes; no camera movement, hit-stop, actor scale, collision, movement speed, or ability duration changes were made. Movement cue timing follows existing local ability execution; this pass does not add new multiplayer ability RPCs.

## Objective tension and accessibility

An objective perimeter arc follows actual capture progress and capture-team color. Overtime gets a restrained perimeter accent and an original synthetic tick whose interval changes from 850 ms toward 350 ms as the current overtime window drains. Rhythm stops outside active overtime; the existing announcements remain edge-triggered. Reduced flashes uses a static overtime accent. Existing intensity/volume settings, fog checks, 48 transient-effect cap, eight-voice cap, four-new-sounds-per-frame budget, and audio priority routing apply. Persistent markers have their separate 64-state budget.

No bitmap assets were generated or third-party assets copied. New visual assets are procedural vectors; new audio accents extend the existing runtime synthesizer. Mana-reclaim pickups, loot, shops, and their reward feedback remain pending the actual gameplay systems.

## Validation

New integration scene checks finite batch mana, authoritative order, ownership, self-shield rejection, hidden occupancy, modal suppression, actual charge/recovery/exhaustion/expiry states, positive defensive contacts, crowd-control deduplication, dash interruption, and overtime rhythm/reset. Existing juice, HUD, playtest smoke, and pre-game scenes also completed with zero failures. A staged 1920×1080 Godot render was visually inspected. This is not a multiplayer stress or timing capture.

The Godot/EOS native process shutdown issue observed before this work persists (0xC0000374 after completed scenes); test completion markers are recorded separately from process exit status. Final validation logs contain no GDScript errors. Existing stale-resource UID and singleton deprecation warnings remain.
