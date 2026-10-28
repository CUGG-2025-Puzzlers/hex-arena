# Gameplay overhaul: first playtest

This branch tests whether concealed preparation, route choices, and teamwork give familiar characters more replayability. Character kits and balance presets remain as authored on this branch.

## Start a session

1. Open the project in Godot 4.6 and allow asset import to finish.
2. Choose **Local / LAN**, host a game, and share the host IP with the other players. Direct internet connections require the existing port forwarding setup.
3. In character selection, the host chooses a preset:
   - **A — Original duel:** existing arena, full information, elimination.
   - **B — Vision duel:** new wall layout, elimination. Toggle limited vision to compare on the same map.
   - **C — 2v2 control:** four players, team-shared vision, central objective, respawns and base recovery.
4. Everyone selects a character. Duplicate characters are allowed. Only the host starts; exactly two/four selected players are required.
5. Teams alternate through the sorted peer roster displayed in the lobby. Each team receives distinct spawn slots.

2v2 is intentionally available through LAN/direct connect only. Existing EOS custom/quick matchmaking remains a duel service and is not expanded to advertise four-player rooms. No EOS credentials are needed for LAN; a missing private credential script falls back to the placeholder template. EOS online play still needs your real ignored credential file.

## Rules

- Living teammates share wall-blocked sight, approximately 500 world units. Allied placed and travelling magic also reveals 180 world units around itself; unclaimed or enemy magic grants no vision, and fizzled/dead-owner magic loses its sight. Enemy players, labels, ranges and prepared magic are concealed outside sight. Moving projectiles appear when entering visible cells. Visibility does not disable collision or damage.
- The rework camera follows the living local player at fixed zoom. It cannot pan or zoom from enemy position. Dead players follow a living ally or their base and contribute no sight.
- Magic remains individually owned. Players cannot transform or launch teammates' preparations. Player damage and hostile special effects are team-aware; friendly shields still block movement and ordinary projectiles under the existing shield rules.
- The central radius-two hex zone opens after 15 seconds. Sole-team occupancy scores one point/second. Extra occupants do not accelerate scoring; empty/contested zones pause it. Dead and protected players do not score.
- First to 60 wins; the eight-minute cap awards the higher score, with equal scores a draw. Team wipes do not end the objective mode.
- Respawn takes five seconds, restores health/mana and resets ability state. One second of protection ends when placing, transforming or launching magic. Owned magic, wires and fields are removed on death.
- At your base, health and mana recover at 20/second after three seconds without damage. Base recovery does not grant immunity.
- Results stay inside the arena. The host can rematch without reconnecting, reselecting characters or rebuilding the networked player tree. Main Menu leaves the session.

Tune the values in `scripts/playtest/playtest_rules.gd`. `WALL_CELLS` in `playtest_match.gd` selects occupied hex coordinates. `HexCells.add_wall()` registers permanent `HexWall` terrain in the existing cell registry, reusing `map_to_local`, `hex_shape` and `hex_polygon_shape` for placement, drawing and collision. Vision and projectile blocking use the exact polygons derived from those same cells. The original arena and tutorial are retained.

## Compare deliberately

Start with experienced players and refresh the old duel. Then compare full and limited vision on the **same new map** with sides/order swapped. Finally play repeated 2v2 control matches, changing teams. Keep combat balance constant during each comparison.

Ask each player: What did you change because of the opponent? Did you successfully infer an unseen setup? Could you respond to ambushes? Did your teammate enable a different play? Would you play the same character again?

Host logs are local JSONL files at `user://overhaul-*.jsonl` (Godot's application data directory). They record settings, start/end, score/occupancy changes, death/respawn and host sight transitions. Existing telemetry retains cast/damage/mana statistics. Host sight transitions describe the host's view, not every team's view.

## Verification

- `godot --headless --path . tests/playtest_smoke.tscn` exercises LOS, team relationships, resource validation, concealed/shared sight, death/respawn/protection and objective scoring.
- `python3 tests/run_network_test.py /path/to/godot` runs four real ENet processes through two rounds with a rematch, using a temporary copy with small proxy textures to control memory. Scripts, scenes, collision shapes and networking rules are unchanged; repository artwork is untouched. Python Pillow is required.
- Four simultaneous full-art headless processes can consume several GB. Use the provided fixture runner instead of exhausting the machine.
- The bundled EOS native extension aborts on Linux shutdown in this environment, including on the pre-rework branch. The runner reports that separately after checking completion markers and rejects gameplay/script errors. It must not be reported as a clean engine exit.

Before a group session, manually check each team's actual view: corners and moving-projectile warnings, ally colors, detached effects, four-player readability, three consecutive rematches and disconnect behavior. Headless checks do not validate visual quality or whether ambushes feel fair.

## Boundaries of this prototype

Fog is presentation filtering for trusted playtesters. All entities are still replicated; this is not cheat-resistant production fog. Cell-sized reveals are deliberate. Long wires/fields are hidden conservatively when their footprint is not fully visible; this may need refinement from playtest feedback. Special area attacks retain their authored shapes, while ordinary moving magic and the pressure lance are blocked by the new walls.

No loot, shop, XP, ultimates, bushes, fog minimap, fizzle refunds, ranked features or 5v5 are included. There are no claims of long-term retention from the initial tests: judge repeated decisions and the desire to rematch with familiar characters.

## Validation recorded for this implementation

On October 28, 2026, using Godot 4.6 stable on Linux:

- Full-art headless rule/scene smoke test reached `PLAYTEST_SMOKE_COMPLETE failures=0`.
- Four actual ENet peers completed two rounds and an in-place rematch, including death/respawn synchronization, using the reduced-art fixture. The runner returned success with no gameplay/script errors, and reported the known EOS native shutdown abort for each process separately.
- Whitespace/diff checks passed. Rendered UI and group gameplay feel still require a manual playtest; no visual QA is claimed by these headless checks.

Magic-sight and hex-wall follow-up: regression coverage includes allied stationary/travelling magic sight, radius limits, hostile/fizzled sources, hex-corner LOS, projectile clipping, occupied terrain placement/transformation, and wall persistence through rematches.
