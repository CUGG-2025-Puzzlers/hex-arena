# Combat feedback

This pass adapts the supported feedback patterns from the Overwatch / League of Legends / Fortnite investigation to Hex-Arena's existing gameplay. It uses original procedural drawing and synthetic audio, with Hex-Arena tuning. It does not contain extracted game assets, recovered proprietary effect graphs, or a claim of identical source-game curves.

## Implemented behavior

| Existing event | Feedback | Integration |
| --- | --- | --- |
| Approved placement | Short hex outline and placement accent | Magic.place_instance_for_player |
| Approved transformation | Distinct hex/ring response and higher accent | Magic.change_state_for_player marks the replacement |
| Approved launch | Directional release stroke, sound and bounded trail | HexCells._launch_approved, only after rolling begins |
| Damage | Target-local impact and distinct incoming bearing cue | Player._apply_damage after immunity/friendly checks and actual-damage clamping |
| Critical health entry | One restrained, rate-limited warning | Confirmed local damage crossing 25%; no full-screen flash |
| Elimination | One local confirmation and brief text | Lethal damage credited to the local attacker; repeated damage at zero HP is suppressed |
| Shield contact / magic destruction | Different contact and break accents | Magic.take_damage; counter-magic burst uses explicit destruction feedback |
| Healing / respawn | Small arc/plus and a rate-limited heal sound | Actual positive health restored; respawn initialization has a separate world accent |
| Crowd control | Distinct chain-like contact accent | Actual positive root/silence extensions |
| Ability activation / ready / denial | World activation accent, local ready border or denial border and sounds | Existing AbilityBase events; natural cooldown expiry announces readiness; reset_for_respawn does not |
| Pressure Lance fully charged | Small charged-state accent | Actual charge-progress crossing |
| Health reduction | Brief trailing segment on the existing segmented bar | Visual-only hold/decay; binding a new player resets the trail |
| Objective phases | Capture/loss, contest, overtime and round/result announcements | Local presentation edges; repeated snapshots do not repeat transitions |
| Menu interaction | Debounced hover/focus sound and distinct activation sound | BaseButton signals; existing native button/focus styles remain in use |

Placement, transformation and launch feedback are triggered from the existing approved replicated paths. Player damage/healing feedback comes from the existing reliable authoritative handlers, rather than stat snapshots. Magic-on-magic contact is cosmetic feedback from the existing peer simulation; it is not a new authoritative collision system.

## Director and readability

Juice is a local autoload. World effects expire quickly and do not scale gameplay roots, collision shapes, time scale, camera transforms or FOV. Projectile residue is thin and bounded. The HUD overlay ignores mouse input and draws incoming damage near the affected player, rather than adding a fixed FPS crosshair.

The director bounds transient world effects at 48 and audio voices at 8, with at most four new audio accents per frame. Critical visual events can evict lower-priority decoration. Critical audio can replace weaker voices and duck less relevant accents. Personal confirmations are non-spatial; world cues use AudioStreamPlayer2D, distance weighting and a simple wall-obstruction reduction. This affects the newly added cues, not every pre-existing authored sound or the music player. It is not a recovered Overwatch path-diversion mixer.

Hostile effects and world sounds require local visibility; world visibility is re-evaluated during effect lifetime. Trails also test segment visibility. Local damage may communicate incoming bearing, but does not place an effect at a concealed attacker's world position. Scene handoffs clear effect references, active voices, gates and pending sound accents. No new RPC or gameplay state is replicated.

Sound & effects is accessible from Home and the in-match FX button. Effect intensity, feedback volume and reduced impact flashes are saved in user://feedback.cfg. The settings window participates in the HUD's modal input lock; closing it does not unlock an overlapping concede dialog. No default game settings are overwritten.

## Scope and exclusions

No global hit-stop, slow motion, camera/FOV kick, full-screen hit flash, damage-number fireworks, announcer chatter, rarity celebration for routine pickups, or mana-refill ultimate celebration was added. Existing authored character animation timings and hitboxes remain unchanged. The new transient envelopes are Hex-Arena tuning, not measured clones of native game values.

Loot, shops, artifacts, XP progression and reclaimable mana motes are not gameplay systems on this branch. This change does not introduce those mechanics or pretend that presentation-only pickups transfer resources. Their feedback integration remains dependent on implementing those mechanics. Per-skin VFX parity, haptics, a complete first-person weapon system and bespoke animations for every character are outside this adaptation to existing Hex-Arena actions.

## REA provenance

REA CLI 6.8.0 inspect-analysis-view was used to re-open the retained evidence bundles for all three installed targets. These projections succeeded. Their bounded artifact inventories identify packages/header observations, not effect definitions or runtime curves:

- Overwatch: parent ev_f2a1d4d302af16ca7313a6531f6add96e0565fba6b5f165c9a90c42f6adafb3d; 1,256 entries, 31 files probed, 10,524 selected bytes read.
- League: parent ev_21a3cb65b8029f58785c8fa09f18e2f7247b2fa90c7740c46c0368245c52eff7; 596 entries, 5 files probed, 1,700 selected bytes read.
- Fortnite: parent ev_807bb9a00f35f3481f59c2825152f4ecf08e0f99967707bd2e219d7163e86fed; 447 entries, 111 files probed, 26,684 selected bytes read.

The pattern choices are supported separately by developer accounts: [Overwatch's listener/threat-based audio](https://media.gdcvault.com/gdc2016/Presentations/Lawlor_Neumann_Overwatch_Play_by_Sound.pdf), [League's visual hierarchy](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), [Lee Sin's contextual feedback](https://www.leagueoflegends.com/en-gb/news/dev/dev-modernizing-the-monk/), and [Fortnite's audio scheduling examples](https://www.unrealengine.com/tech-blog/procedural-music-generation-with-quartz?lang=en). Fortnite-style loot presentation remains a future integration because loot is absent.

## Validation

Run tests/juice_feedback.tscn for confirmed versus rejected damage, actual cast/transform/launch hooks, unchanged collision scale, health trails, correct incoming bearing, one-time credit/readiness, modal input ownership, hidden-effect suppression, objective transition deduplication, spatial versus personal audio, voice/effect priority budgets and scene cleanup. Also run the existing HUD, pre-game and playtest smoke suites.

The optional --preview=/absolute/path.png argument produces a staged in-engine still. Only decorative effect processing is frozen for that screenshot so rendering startup cannot consume the short effect lifetimes; it is not a timing benchmark or a recording of a live match.

Recorded Windows Godot 4.7.2 runs reached JUICE_FEEDBACK_COMPLETE failures=0, HUD_FEEDBACK_COMPLETE failures=0, PREGAME_SCREENS_COMPLETE failures=0 and PLAYTEST_SMOKE_COMPLETE failures=0 without final GDScript errors. Four actual ENet peers completed two rounds and a rematch. The network fixture used proxy textures and copied the Windows addon binaries rather than creating a symlink; gameplay scripts and RPC behavior were unchanged. Its strict harness still reported environment log/certificate access errors. The known native Windows shutdown failure 0xC0000374 persisted after completion. These are completed assertions, not clean engine exits. Verify with the branch-targeted Godot 4.6 and conduct a multiplayer visual/audio playtest before release.
