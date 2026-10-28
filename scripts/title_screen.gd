extends Control

const MODE_QUICK := "quick"
const MODE_CUSTOM := "custom"
const MODE_BOT := "bot"
const MODE_TUTORIAL := "tutorial"
const MODE_LOCAL := "local"

const HERO_SPLASHES := {
	Util.Character.Hekaset: preload(
		"res://assets/textures/hekaset_splash.png"
	),
	Util.Character.Zilo: preload(
		"res://assets/textures/zilo_splash.png"
	),
	Util.Character.WaterOrbA: preload(
		"res://assets/textures/water_orb/water_orb_razor_splash.png"
	),
	Util.Character.WaterOrbB: preload(
		"res://assets/textures/water_orb/water_orb_flow_splash.png"
	),
	Util.Character.Aurora: preload(
		"res://assets/textures/aurora/aurora_splash.png"
	),
}

const HERO_ICONS := {
	Util.Character.Hekaset: preload(
		"res://assets/textures/hekaset_icon.png"
	),
	Util.Character.Zilo: preload(
		"res://assets/textures/zilo_icon.png"
	),
	Util.Character.WaterOrbA: preload(
		"res://assets/textures/water_orb/water_orb_razor_icon.png"
	),
	Util.Character.WaterOrbB: preload(
		"res://assets/textures/water_orb/water_orb_flow_icon.png"
	),
	Util.Character.Aurora: preload(
		"res://assets/textures/aurora/aurora_icon.png"
	),
}

const HERO_ROLES := {
	Util.Character.Hekaset: "ARCANE MAGE",
	Util.Character.Zilo: "CLOSE-RANGE DUELIST",
	Util.Character.WaterOrbA: "RAZOR CURRENT",
	Util.Character.WaterOrbB: "FLOW CONTROLLER",
	Util.Character.Aurora: "LIGHT CONTROLLER",
}

const HERO_DESCRIPTIONS := {
	Util.Character.Hekaset:
		"Places light and heavy magic, then changes it to control space.",
	Util.Character.Zilo:
		"Roots a target, closes the gap, and deals high close-range damage.",
	Util.Character.WaterOrbA:
		"Shapes water into fast, sharp attacks and close-range pressure.",
	Util.Character.WaterOrbB:
		"Uses flowing water magic to redirect fights and control lanes.",
	Util.Character.Aurora:
		"Uses silence, slowing fields, healing light, and stasis.",
}

const MODE_NAMES := {
	MODE_QUICK: "QUICK MATCH",
	MODE_CUSTOM: "CUSTOM LOBBY",
	MODE_BOT: "PLAY VS BOT",
	MODE_TUTORIAL: "TUTORIAL",
	MODE_LOCAL: "LOCAL PLAY",
}

const MODE_DESCRIPTIONS := {
	MODE_QUICK: "Find an online opponent through EOS matchmaking.",
	MODE_CUSTOM: "Create a lobby or find one hosted by another player.",
	MODE_BOT: "Choose both heroes and play against the training bot.",
	MODE_TUTORIAL: "Learn movement, magic placement, and transformations.",
	MODE_LOCAL: "Host or join a direct LAN game.",
}

@onready var _home_view: Control = %HomeView
@onready var _play_view: Control = %PlayView
@onready var _heroes_view: Control = %HeroesView
@onready var _patch_view: Control = %PatchView
@onready var _custom_lobby_panel: Control = %CustomLobbyPanel
@onready var _local_panel: Control = %LocalPanel
@onready var _join_container: Control = %JoinContainer
@onready var _lobbies_container: Control = %LobbiesContainer

@onready var _hero_art: TextureRect = %HeroArt
@onready var _preview_art: TextureRect = %PreviewArt
@onready var _hero_name_label: Label = %HeroNameLabel
@onready var _hero_role_label: Label = %HeroRoleLabel
@onready var _left_hero_name_label: Label = %LeftHeroNameLabel
@onready var _left_hero_role_label: Label = %LeftHeroRoleLabel
@onready var _hero_description_label: Label = %HeroDescriptionLabel
@onready var _preview_name_label: Label = %PreviewNameLabel
@onready var _preview_role_label: Label = %PreviewRoleLabel
@onready var _preview_description_label: Label = %PreviewDescriptionLabel

@onready var _selected_mode_label: Label = %SelectedModeLabel
@onready var _selected_mode_description: Label = %SelectedModeDescription
@onready var _main_play_button: Button = %MainPlayButton

@onready var _player_name_label: Label = %PlayerNameLabel
@onready var _player_progress_label: Label = %PlayerProgressLabel
@onready var _status_label: Label = %StatusLabel
@onready var _cancel_queue_button: Button = %CancelQueueButton
@onready var _name_error_label: Label = %NameErrorLabel

@onready var _lobbies_grid: GridContainer = %LobbiesGrid
@onready var _lobby_search: LineEdit = %LobbySearch
@onready var _ip_line_edit: LineEdit = %IPLineEdit
@onready var _port_line_edit: LineEdit = %PortLineEdit
@onready var _ip_error_label: Label = %IPErrorLabel
@onready var _port_error_label: Label = %PortErrorLabel

var _selected_mode := MODE_QUICK
var _selected_character: Util.Character = Util.Character.Hekaset
var _preview_character: Util.Character = Util.Character.Hekaset
var _current_lobbies: Array[HLobby] = []
var _quick_match_cancelled := false


func _ready() -> void:
	_initialise_theme()
	_connect_navigation()
	_connect_modes()
	_connect_heroes()
	_connect_network_actions()

	if LobbyMatchmakingManager.has_signal("lobby_action_failed"):
		LobbyMatchmakingManager.lobby_action_failed.connect(
			_on_lobby_action_failed
		)
	if LobbyMatchmakingManager.has_signal("quick_match_status"):
		LobbyMatchmakingManager.quick_match_status.connect(
			_on_quick_match_status
		)

	_name_error_label.hide()
	_ip_error_label.hide()
	_port_error_label.hide()
	_status_label.text = ""
	_cancel_queue_button.hide()
	_cancel_queue_button.pressed.connect(_on_cancel_quick_match)

	_refresh_profile()
	_initialise_character()
	_update_mode_display()
	_show_view(_home_view)

	Telemetry.track("main_menu_viewed")


func _initialise_theme() -> void:
	var custom_theme := load(
		"res://ui/themes/hex_red_teal.tres"
	) as Theme

	if custom_theme == null:
		push_warning("Could not load the Hex Arena UI theme.")
		return

	if custom_theme.has_method("ensure_built"):
		custom_theme.call("ensure_built")

	# Applying the same cached resource here guarantees that this menu and
	# later scenes use the populated theme after the SceneTree exists.
	theme = custom_theme


func _connect_navigation() -> void:
	%HomeTabButton.pressed.connect(_show_home)
	%PlayTabButton.pressed.connect(_show_play)
	%HeroesTabButton.pressed.connect(_show_heroes)
	%PatchTabButton.pressed.connect(_show_patch)
	%AccountButton.pressed.connect(_on_account_pressed)
	%ChangeHeroButton.pressed.connect(_show_heroes)
	%ChooseModeButton.pressed.connect(_show_play)
	%ViewPatchButton.pressed.connect(_show_patch)
	%PlayBackButton.pressed.connect(_show_home)
	%HeroesBackButton.pressed.connect(_show_home)
	%PatchBackButton.pressed.connect(_show_home)
	%MainPlayButton.pressed.connect(_launch_selected_mode)


func _connect_modes() -> void:
	%QuickMatchModeButton.pressed.connect(
		_select_mode.bind(MODE_QUICK)
	)
	%CustomLobbyModeButton.pressed.connect(
		_select_mode.bind(MODE_CUSTOM)
	)
	%BotModeButton.pressed.connect(
		_select_mode.bind(MODE_BOT)
	)
	%TutorialModeButton.pressed.connect(
		_select_mode.bind(MODE_TUTORIAL)
	)
	%LocalModeButton.pressed.connect(
		_select_mode.bind(MODE_LOCAL)
	)


func _connect_heroes() -> void:
	var hero_buttons := {
		Util.Character.Hekaset: %HekasetHeroButton,
		Util.Character.Zilo: %ZiloHeroButton,
		Util.Character.WaterOrbA: %AquaAHeroButton,
		Util.Character.WaterOrbB: %AquaBHeroButton,
		Util.Character.Aurora: %AuroraHeroButton,
	}

	for character in hero_buttons:
		var button: Button = hero_buttons[character]
		button.icon = HERO_ICONS[character]
		button.expand_icon = true
		button.add_theme_constant_override(
			&"icon_max_width",
			48
		)
		button.pressed.connect(_preview_hero.bind(character))

	%SelectHeroButton.pressed.connect(_select_previewed_hero)


func _connect_network_actions() -> void:
	%CreateLobbyButton.pressed.connect(_on_create_lobby)
	%FindLobbiesButton.pressed.connect(_on_find_lobbies)
	%CustomBackButton.pressed.connect(_show_home)

	%HostGameButton.pressed.connect(_on_host_game)
	%JoinGameButton.pressed.connect(_show_join_menu)
	%LocalBackButton.pressed.connect(_show_home)

	%ConnectButton.pressed.connect(_on_connect)
	%JoinBackButton.pressed.connect(_show_local_menu)

	%LobbiesBackButton.pressed.connect(_show_custom_lobby_menu)
	%RefreshButton.pressed.connect(_on_find_lobbies)
	_lobby_search.text_changed.connect(_on_lobby_search_changed)


func _initialise_character() -> void:
	var saved_character = MultiplayerManager.player_info.get(
		"character",
		Util.Character.None
	)

	if saved_character in HERO_SPLASHES:
		_selected_character = saved_character
	else:
		MultiplayerManager.player_info["character"] = _selected_character

	_preview_character = _selected_character
	_update_selected_hero()
	_update_preview_hero()


func _refresh_profile() -> void:
	var display_name := GameManager.player_name.strip_edges()
	if display_name.is_empty():
		display_name = "Player"

	_player_name_label.text = display_name
	var xp_needed := 5 + (GameManager.level * 5)
	_player_progress_label.text = "Level %d  •  %d / %d XP" % [
		GameManager.level,
		GameManager.xp,
		xp_needed,
	]


func _show_view(view: Control) -> void:
	for candidate: Control in [
		_home_view,
		_play_view,
		_heroes_view,
		_patch_view,
		_custom_lobby_panel,
		_local_panel,
		_join_container,
		_lobbies_container,
	]:
		candidate.visible = candidate == view

	_status_label.text = ""
	_update_navigation_state(view)


func _update_navigation_state(view: Control) -> void:
	%HomeTabButton.disabled = view == _home_view
	%PlayTabButton.disabled = view == _play_view
	%HeroesTabButton.disabled = view == _heroes_view
	%PatchTabButton.disabled = view == _patch_view


func _show_home() -> void:
	_show_view(_home_view)


func _show_play() -> void:
	_show_view(_play_view)


func _show_heroes() -> void:
	_preview_character = _selected_character
	_update_preview_hero()
	_show_view(_heroes_view)


func _show_patch() -> void:
	_show_view(_patch_view)


func _show_custom_lobby_menu() -> void:
	_show_view(_custom_lobby_panel)


func _show_local_menu() -> void:
	_show_view(_local_panel)


func _show_join_menu() -> void:
	_show_view(_join_container)
	_ip_line_edit.text = ""
	_port_line_edit.text = ""
	_ip_error_label.hide()
	_port_error_label.hide()


func _select_mode(mode: String) -> void:
	_selected_mode = mode
	_update_mode_display()
	Telemetry.track("mode_selected", {"mode": mode})
	_show_home()


func _update_mode_display() -> void:
	_selected_mode_label.text = MODE_NAMES[_selected_mode]
	_selected_mode_description.text = MODE_DESCRIPTIONS[_selected_mode]

	match _selected_mode:
		MODE_CUSTOM, MODE_LOCAL:
			_main_play_button.text = "OPEN"
		MODE_TUTORIAL:
			_main_play_button.text = "START"
		_:
			_main_play_button.text = "PLAY"


func _launch_selected_mode() -> void:
	match _selected_mode:
		MODE_QUICK:
			_on_quick_match()
		MODE_CUSTOM:
			_show_custom_lobby_menu()
		MODE_BOT:
			_on_bot_match()
		MODE_TUTORIAL:
			_on_start_tutorial()
		MODE_LOCAL:
			_show_local_menu()


func _preview_hero(character: Util.Character) -> void:
	_preview_character = character
	_update_preview_hero()


func _select_previewed_hero() -> void:
	_selected_character = _preview_character
	MultiplayerManager.player_info["character"] = _selected_character
	_update_selected_hero()
	Telemetry.track(
		"character_selected",
		{
			"mode": "main_menu",
			"character": Util.get_character_display_name(
				_selected_character
			),
		}
	)
	_show_home()


func _update_selected_hero() -> void:
	var display_name := Util.get_character_display_name(
		_selected_character
	).to_upper()
	var role: String = HERO_ROLES[_selected_character]
	var description: String = HERO_DESCRIPTIONS[_selected_character]

	_hero_art.texture = HERO_SPLASHES[_selected_character]
	_hero_name_label.text = display_name
	_hero_role_label.text = role
	_left_hero_name_label.text = display_name
	_left_hero_role_label.text = role
	_hero_description_label.text = description


func _update_preview_hero() -> void:
	_preview_art.texture = HERO_SPLASHES[_preview_character]
	_preview_name_label.text = Util.get_character_display_name(
		_preview_character
	).to_upper()
	_preview_role_label.text = HERO_ROLES[_preview_character]
	_preview_description_label.text = HERO_DESCRIPTIONS[
		_preview_character
	]


func _on_bot_match() -> void:
	Telemetry.track("mode_selected", {"mode": "bot"})
	MultiplayerManager.player_info["name"] = _usable_player_name()
	MultiplayerManager.begin_bot_character_select()


func _on_start_tutorial() -> void:
	Telemetry.track("tutorial_started")
	SceneManager.load_tutorial()


func _on_account_pressed() -> void:
	SceneManager.load_account_page()


func _on_quick_match() -> void:
	if not _validate_account_name():
		return

	_quick_match_cancelled = false
	_set_busy(true, "Searching for an opponent…")
	_cancel_queue_button.show()
	_cancel_queue_button.disabled = false
	Telemetry.track("matchmaking_entered")

	var success := await LobbyMatchmakingManager.quick_match(
		GameManager.player_name
	)
	if not LobbyMatchmakingManager.is_quick_match_active():
		_cancel_queue_button.hide()
	if not success and not _quick_match_cancelled:
		_set_busy(false, "Quick Match failed. Try again.")


func _on_cancel_quick_match() -> void:
	_quick_match_cancelled = true
	_cancel_queue_button.disabled = true
	_status_label.text = "Cancelling search…"
	await LobbyMatchmakingManager.cancel_quick_match()
	_cancel_queue_button.hide()
	_set_busy(false, "Search cancelled.")


func _on_create_lobby() -> void:
	if not _validate_account_name():
		return

	_set_busy(
		true,
		"Creating %s's lobby…" % GameManager.player_name
	)
	var success := await LobbyMatchmakingManager.create_lobby(
		GameManager.player_name
	)
	if not success:
		_set_busy(false, "Could not create lobby.")


func _on_find_lobbies() -> void:
	if not _validate_account_name():
		return

	_set_busy(true, "Finding lobbies…")
	_current_lobbies = await LobbyMatchmakingManager.find_lobbies(
		GameManager.player_name
	)
	_set_busy(false, "")
	_show_view(_lobbies_container)
	_render_lobbies(_lobby_search.text)


func _on_lobby_search_changed(filter_text: String) -> void:
	_render_lobbies(filter_text)


func _render_lobbies(filter_text: String) -> void:
	_clear_lobby_results()

	var filter := filter_text.strip_edges().to_lower()
	var displayed := 0

	for lobby: HLobby in _current_lobbies:
		var lobby_name := (
			LobbyMatchmakingManager.get_lobby_host_name(lobby)
		)

		if (
			not filter.is_empty()
			and not lobby_name.to_lower().contains(filter)
		):
			continue

		displayed += 1
		_add_lobby_label(lobby_name)
		_add_lobby_label(
			LobbyMatchmakingManager.get_lobby_mode_label(lobby)
		)
		_add_lobby_label(
			"%s/%s" % [lobby.members.size(), lobby.max_members]
		)

		var join_button := Button.new()
		join_button.text = "JOIN"
		join_button.theme_type_variation = &"TealButton"
		join_button.pressed.connect(
			_on_lobby_join_pressed.bind(lobby)
		)
		_lobbies_grid.add_child(join_button)

	if displayed == 0:
		var empty := Label.new()
		empty.text = "No matching lobbies"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.theme_type_variation = &"MutedLabel"
		_lobbies_grid.add_child(empty)


func _add_lobby_label(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lobbies_grid.add_child(label)


func _clear_lobby_results() -> void:
	for child: Node in _lobbies_grid.get_children():
		if child.get_meta("header", false):
			continue
		_lobbies_grid.remove_child(child)
		child.queue_free()


func _on_lobby_join_pressed(lobby: HLobby) -> void:
	_set_busy(true, "Joining lobby…")
	var success := await LobbyMatchmakingManager.join_lobby(
		lobby,
		GameManager.player_name
	)
	if not success:
		_set_busy(false, "Could not join lobby.")


func _on_host_game() -> void:
	if not _validate_account_name():
		return

	Telemetry.track("mode_selected", {"mode": "local_host"})
	MultiplayerManager.create_game(GameManager.player_name)


func _on_connect() -> void:
	if not _validate_account_name():
		return

	var errors := 0
	var ip := _ip_line_edit.text.strip_edges()

	if ip.is_empty():
		ip = MultiplayerManager.SERVER_IP

	if not ip.is_valid_ip_address():
		errors += 1
		_ip_error_label.show()
	else:
		_ip_error_label.hide()

	var port_text := _port_line_edit.text.strip_edges()
	var port := MultiplayerManager.DEFAULT_PORT

	if not port_text.is_empty():
		if not port_text.is_valid_int():
			errors += 1
		else:
			port = port_text.to_int()

	if port <= 0 or port > 65535:
		errors += 1
		_port_error_label.show()
	else:
		_port_error_label.hide()

	if errors > 0:
		return

	Telemetry.track("mode_selected", {"mode": "local_join"})
	MultiplayerManager.join_game(
		GameManager.player_name,
		ip,
		port
	)


func _validate_account_name() -> bool:
	var valid := GameManager.is_valid_name(GameManager.player_name)
	_name_error_label.visible = not valid
	return valid


func _usable_player_name() -> String:
	if GameManager.is_valid_name(GameManager.player_name):
		return GameManager.player_name
	return "Player"


func _set_busy(busy: bool, message: String) -> void:
	_status_label.text = message

	for button: Button in get_tree().get_nodes_in_group(
		"menu_action"
	):
		button.disabled = busy


func _on_lobby_action_failed(reason: String) -> void:
	_set_busy(false, reason)


func _on_quick_match_status(message: String) -> void:
	_status_label.text = message
	if (
		message == "Opponent found. Connecting…"
		or message.begins_with("Creating a match.")
	):
		_cancel_queue_button.disabled = true
