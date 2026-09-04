# Hex Arena EOS Lobby / Lobby Room Handoff

Last updated: 2026-06-28

This file is a pickup note for continuing the Hex Arena EOS lobby/matchmaking work on another computer.

## Project

Project path used during this work:

```text
C:\Users\lavam\Desktop\hex-arena
```

Main files involved:

```text
scripts/autoloads/multiplayer_manager.gd
scripts/autoloads/lobby_matchmaking_manager.gd
scripts/title_screen.gd
scenes/title_screen.tscn
scenes/lobby_room_screen.tscn
scripts/lobby_room_screen.gd
scenes/lobby_player_card.tscn
scripts/lobby_player_card.gd
project.godot
```

Important credential rule:

```text
Do not commit scripts/eos/EosCredentials.gd or scripts/eos/EosCredentials.gd.uid.
```

Those should be ignored. Use a template file for teammates instead.

## Big Picture

The project originally used ENet for multiplayer:

```text
Host: ENetMultiplayerPeer.create_server(DEFAULT_PORT, 2)
Client: ENetMultiplayerPeer.create_client(ip, port)
```

We started moving lobby matchmaking to EOS. At first, EOS lobbies only stored host IP/port, but that still depended on LAN/UPNP/port forwarding. Then we transitioned the actual transport to EOSG P2P:

```text
EOS login
EOS lobby discovery
EOS lobby join
EOSGMultiplayerPeer P2P transport
Godot multiplayer RPCs over EOSGMultiplayerPeer
```

The important change is that clients no longer connect to:

```text
HOST_IP + HOST_PORT
```

They connect through EOS using:

```text
lobby.owner_product_user_id + MultiplayerManager.EOS_SOCKET_NAME
```

EOS P2P handles NAT punchthrough and can use Epic relay if direct P2P is not possible.

## EOSG Transport Work Done

In `scripts/autoloads/multiplayer_manager.gd`, we added:

```gdscript
const EOS_SOCKET_NAME = "HexArenaDuel"
```

Important gotcha discovered:

```text
EOSG socket IDs can only contain letters and numbers.
```

This failed:

```gdscript
"HEX_ARENA_DUEL"
```

because underscores are invalid. It returned error `20` from `create_server`. The working socket name is:

```gdscript
"HexArenaDuel"
```

Added EOS host function:

```gdscript
create_eos_game(player_name: String) -> bool
```

Current behavior:

```text
- checks HAuth.product_user_id
- creates EOSGMultiplayerPeer
- calls create_server(EOS_SOCKET_NAME)
- assigns multiplayer.multiplayer_peer
- registers host player as peer 1
- emits player_connected
- currently loads character select
```

Added EOS client function:

```gdscript
join_eos_game(player_name: String, host_product_user_id) -> bool
```

Current behavior:

```text
- creates EOSGMultiplayerPeer
- calls create_client(EOS_SOCKET_NAME, host_product_user_id)
- assigns multiplayer.multiplayer_peer
- stores local player name
- prints EOS P2P connection message
```

The old ENet functions still exist as fallback/debug:

```gdscript
create_game(player_name)
join_game(player_name, ip, port)
```

## Lobby Matchmaking Work Done

In `scripts/autoloads/lobby_matchmaking_manager.gd`, the manager owns EOS lobby creation/search/join/cleanup.

Current signals:

```gdscript
signal lobby_action_failed(reason: String)
signal lobby_created(lobby: HLobby)
signal lobby_joined(lobby: HLobby)
signal lobby_hidden(lobby: HLobby)
```

Current lobby constants:

```gdscript
const BUCKET_ID := "hex_arena_duel_v1"
const MODE := "duel"
const DEFAULT_BUILD := "dev"

const ATTR_MODE := "MODE"
const ATTR_BUILD := "BUILD"
const ATTR_HOST_NAME := "HOST_NAME"
const ATTR_SOCKET_NAME := "SOCKET_NAME"
```

Old ENet constants still exist but should eventually be removed if no longer used:

```gdscript
ATTR_HOST_IP
ATTR_HOST_PORT
```

### `_ensure_eos_ready(player_name)`

Current purpose:

```text
- creates HCredentials using EosCredentials
- calls HPlatform.setup_eos_async(credentials)
- logs in anonymously with HAuth.login_anonymous_async(player_name) if needed
- verifies HAuth.product_user_id
- verifies EOSGMultiplayerPeer.get_local_user_id()
- sets _eos_ready = true
```

Anonymous login is currently used for development. For production, likely switch to a real account login flow such as account portal/dev auth/launcher flow. The lobby and P2P code should still use Product User IDs either way.

### `create_lobby(player_name)`

Current flow:

```text
1. guard _is_busy
2. ensure EOS ready
3. create public advertised EOS lobby
4. add lobby attributes
5. start EOSG host transport using MultiplayerManager.create_eos_game(player_name)
6. store current_lobby
7. set is_host = true
8. emit lobby_created
```

Current lobby attributes added:

```text
HOST_NAME = clean player name
MODE = duel
BUILD = dev
SOCKET_NAME = MultiplayerManager.EOS_SOCKET_NAME
```

Old ENet connection attribute logic is commented out:

```text
HOST_IP
HOST_PORT
```

### `find_lobbies(player_name)`

Current flow:

```text
1. guard _is_busy
2. ensure EOS ready
3. search by bucket id: hex_arena_duel_v1
4. handle search failure / no lobbies / no joinable lobbies with different messages
5. return filtered joinable lobbies
```

### `_filter_joinable_lobbies(lobbies)`

Current checks:

```text
- lobby exists and is valid
- available_slots > 0
- not owned by current user
- MODE matches
- BUILD matches
- SOCKET_NAME matches MultiplayerManager.EOS_SOCKET_NAME
```

This no longer checks IP/port.

### `join_lobby(lobby, player_name)`

Current flow:

```text
1. guard _is_busy
2. validate lobby
3. ensure EOS ready
4. save host_product_user_id from lobby.owner_product_user_id
5. join EOS lobby with HLobbies.join_async(lobby)
6. store current_lobby
7. set is_host = false
8. call MultiplayerManager.join_eos_game(player_name, host_product_user_id)
9. if EOS game join fails, leave the lobby and clear state
10. emit lobby_joined
```

### Cleanup / hide

Implemented:

```gdscript
cleanup_lobby()
hide_current_lobby_from_search()
```

Host destroys the lobby on cleanup. Client leaves the lobby on cleanup.

When host sees player count reach 2, it hides the lobby from search by changing permission level to:

```gdscript
EOS.Lobby.LobbyPermissionLevel.InviteOnly
```

## Important Current Design Issue

`MultiplayerManager.create_eos_game()` currently calls:

```gdscript
SceneManager.load_character_select()
```

For a dedicated lobby room flow, this should eventually change.

Desired future flow:

```text
Create/join EOS lobby
Start EOSG transport
Go to LobbyRoomScreen
Host presses Start
Then transition both players to CharacterSelect
```

So later, consider moving scene transitions out of `create_eos_game()` / `join_eos_game()` and into the caller/UI flow.

## Lobby Room Screen Work Done

Created:

```text
scenes/lobby_room_screen.tscn
scripts/lobby_room_screen.gd
```

Current scene structure:

```text
LobbyRoomScreen (Control)
„¤„Ÿ„Ÿ Background (ColorRect)
    „¤„Ÿ„Ÿ MarginContainer
        „¤„Ÿ„Ÿ HBoxContainer
            „¥„Ÿ„Ÿ PlayerView (PanelContainer)
            „¤„Ÿ„Ÿ RightPanel (PanelContainer)
                „¤„Ÿ„Ÿ VBoxContainer
                    „¥„Ÿ„Ÿ PlayerList (VBoxContainer)
                    „    „¤„Ÿ„Ÿ Label: "Player List"
                    „¤„Ÿ„Ÿ Chat (VBoxContainer)
                        „¥„Ÿ„Ÿ Label: "Chat"
                        „¥„Ÿ„Ÿ ChatScroll (ScrollContainer)
                        „    „¤„Ÿ„Ÿ ChatBox (RichTextLabel)
                        „¤„Ÿ„Ÿ ChatInputRow (HBoxContainer)
                            „¥„Ÿ„Ÿ ChatInput (LineEdit)
                            „¤„Ÿ„Ÿ SendButton (Button)
```

Current layout choices:

```text
- LobbyRoomScreen root is Control and fills screen.
- Background is ColorRect and fills screen.
- MarginContainer fills screen and has 32px margins.
- Main layout uses HBoxContainer.
- PlayerView is left side and has stretch ratio 3.
- RightPanel is right side.
- Chat has a ScrollContainer around ChatBox.
- ChatInputRow no longer expands vertically.
- SendButton text is "Send".
```

The script `scripts/lobby_room_screen.gd` is currently basically empty.

## Lobby Player Card Work Started

Created:

```text
scenes/lobby_player_card.tscn
scripts/lobby_player_card.gd
```

This was started after the lobby room screen. The user said they wanted to commit the lobby room screen without the player card, so treat player card as separate/in-progress work unless already committed intentionally.

Current card scene structure:

```text
LobbyPlayerCard (PanelContainer)
„¤„Ÿ„Ÿ MarginContainer
    „¤„Ÿ„Ÿ VBoxContainer
        „¥„Ÿ„Ÿ Avatar (TextureRect)
        „¤„Ÿ„Ÿ InfoContainer (VBoxContainer)
            „¥„Ÿ„Ÿ NameLabel (Label)
            „¥„Ÿ„Ÿ StatusLabel (Label)
            „¤„Ÿ„Ÿ RoleLabel (Label)
```

Current style:

```text
- Card custom minimum size: 220 x 280
- Panel has StyleBoxFlat background color
- Border width: 4
- Margins: 16
- Avatar minimum size: 160 x 160
- Avatar is centered/stable instead of vertically stretching weirdly
- Labels are horizontally centered
```

Current script references:

```gdscript
@onready var avatar: TextureRect = $MarginContainer/VBoxContainer/Avatar
@onready var name_label: Label = $MarginContainer/VBoxContainer/InfoContainer/NameLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/InfoContainer/StatusLabel
@onready var role_label: Label = $MarginContainer/VBoxContainer/InfoContainer/RoleLabel
```

Current `set_player_info`:

```gdscript
func set_player_info(player_name, is_ready, role, avatar_texture):
    name_label.text = str(player_name)
    status_label.text = "Ready" if is_ready else "Not Ready"
    role_label.text = str(role)
    if avatar_texture:
        avatar.texture = avatar_texture
```

The original intended visual layout is:

```text
„¡„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„¢   VS   „¡„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„¢
„ Avatar „         „ Avatar „ 
„ Player1„         „ Player2„ 
„ Ready? „         „ Ready? „ 
„¤„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„£        „¤„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„Ÿ„£
```

## Next Steps

### 1. Decide what to commit now

If committing only lobby room screen, stage only:

```powershell
git add scenes/lobby_room_screen.tscn scripts/lobby_room_screen.gd
```

Also include these if they exist and belong to the lobby room screen:

```powershell
git add scenes/lobby_room_screen.tscn.uid scripts/lobby_room_screen.gd.uid
```

Do not stage player card files if saving that for a later commit:

```text
scenes/lobby_player_card.tscn
scripts/lobby_player_card.gd
*.uid for those files
```

Suggested commit message:

```text
Add lobby room screen layout
```

### 2. Finish player card later

Next small tasks:

```text
- Add a placeholder avatar texture or styled placeholder background.
- Maybe remove RoleLabel if the VS layout makes roles obvious.
- Optionally add corner radius to the StyleBoxFlat.
- Test card instancing inside LobbyRoomScreen.
```

### 3. Add player cards to LobbyRoomScreen

Target PlayerView structure:

```text
PlayerView (PanelContainer)
„¤„Ÿ„Ÿ CenterContainer
    „¤„Ÿ„Ÿ HBoxContainer
        „¥„Ÿ„Ÿ HostPlayerCard (instance of lobby_player_card.tscn)
        „¥„Ÿ„Ÿ VSLabel (Label, text = "VS")
        „¤„Ÿ„Ÿ OtherPlayerCard (instance of lobby_player_card.tscn)
```

Set HBox alignment/separation:

```text
Alignment: Center
Separation: 48 or similar
```

Then the lobby room script can call:

```gdscript
host_player_card.set_player_info(host_name, host_ready, "Host", null)
other_player_card.set_player_info(other_name, other_ready, "Player", null)
```

### 4. Wire LobbyRoomScreen script

`lobby_room_screen.gd` should eventually:

```text
- read LobbyMatchmakingManager.current_lobby
- display host/player names
- listen to lobby updates if EOSG exposes a lobby_updated signal
- update player cards when members change
- handle Leave button
- handle Ready button
- host-only Start button
```

Likely node references:

```gdscript
@onready var chat_box: RichTextLabel = ...
@onready var chat_input: LineEdit = ...
@onready var send_button: Button = ...
@onready var host_player_card = ...
@onready var other_player_card = ...
```

### 5. Change the scene transition flow

Currently EOS host creation jumps to character select. For the lobby room flow, change the design so:

```text
MultiplayerManager.create_eos_game only starts transport.
MultiplayerManager.join_eos_game only starts transport.
Lobby/UI decides what screen to load next.
```

Desired flow:

```text
Title/Lobby Browser
-> create or join lobby
-> LobbyRoomScreen
-> host presses Start
-> both players load CharacterSelect
```

This may require an RPC or EOS lobby RTC/data message so clients transition together.

### 6. Add Ready / Start behavior

V1 options:

```text
Option A: Use EOS lobby member attributes for READY.
Option B: Use existing Godot multiplayer RPCs over EOSG.
```

Recommended for now:

```text
Use Godot multiplayer RPCs once EOSG transport is connected.
```

Keep EOS lobby attributes mostly for discovery/listing, not fast gameplay state.

### 7. Add chat later

The UI exists, but chat is not wired.

Possible transport choices:

```text
- Use Godot RPC over EOSG for in-lobby chat after P2P is connected.
- Or enable EOS lobby RTC data later if chat should exist before game transport starts.
```

For current flow, EOSG transport starts during create/join, so RPC chat is probably simpler.

### 8. Cleanup old ENet lobby leftovers

After EOSG lobby matchmaking is stable, remove/comment cleanup:

```text
ATTR_HOST_IP
ATTR_HOST_PORT
_get_host_ip()
_is_usable_host_ip()
old ENet endpoint comments/helpers
```

Keep old manual ENet host/join methods only if you still want debug fallback.

### 9. Production login later

Current dev login uses:

```gdscript
HAuth.login_anonymous_async(player_name)
```

Production probably should use a real account login flow, such as account portal/dev auth/launcher/platform login.

The rest of the lobby/P2P flow still uses Product User IDs, so most transport code should not need to change.

## Known Gotchas

### EOSG socket name

Must be alphanumeric only:

```text
Good: HexArenaDuel
Bad: HEX_ARENA_DUEL
```

### `.uid` files

Godot 4 `.uid` files are stable resource IDs. Commit `.uid` files for normal scenes/scripts, but do not commit credential `.uid` files.

### Git divergence

If local and remote branch diverge:

```powershell
git pull --rebase
git push
```

Avoid force push unless you intentionally want to overwrite remote commits.

### Current workspace caveat

Some files may be staged/unstaged separately. Check before committing:

```powershell
git status --short
```

If you accidentally staged too much:

```powershell
git restore --staged .
```

Then stage only what you want.