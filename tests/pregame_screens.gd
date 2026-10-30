extends Node

var failures: int = 0
var capture_dir: String = ""

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PREGAME TEST FAILED: " + message)

func _ready() -> void:
	Telemetry.enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			capture_dir = argument.trim_prefix("--screenshots=")
	call_deferred("run")

func open_screen(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	return screen

func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	check(result == OK, "save rendered " + name)

func run() -> void:
	Overhaul.reset_for_legacy()
	GameManager.player_name = "Player"
	MultiplayerManager.player_info["name"] = "Player"
	MultiplayerManager.player_info["character"] = Util.Character.Hekaset
	var menu := open_screen("res://scenes/title_screen.tscn")
	check(menu._home_view.visible and not menu._play_view.visible, "home opens as the only active view")
	check(menu._hero_art.texture != null, "existing hero splash remains wired")
	check(not menu._main_play_button.is_visible_in_tree(), "Home has no second launch action")
	await capture("pregame-home")
	menu.get_node("%PlayTabButton").grab_focus()
	await capture("pregame-home-focus")
	menu.get_node("%PlayTabButton").release_focus()
	menu.get_node("%PlayTabButton").pressed.emit()
	check(menu._play_view.visible and not menu._home_view.visible, "Play navigation opens mode gallery")
	check(not menu.get_node("%HomeNavigation").visible, "large home navigation does not overlap subpages")
	await capture("pregame-modes")
	menu.get_node("%BotModeButton").pressed.emit()
	check(menu._selected_mode == "bot" and menu._play_view.visible, "mode selection stays on Play")
	check(menu._main_play_button.text == "CHOOSE HEROES", "bot action says what it does")
	var expected_actions := {"quick": "FIND MATCH", "custom": "OPEN LOBBY", "bot": "CHOOSE HEROES", "tutorial": "START TUTORIAL", "local": "OPEN LAN"}
	for mode in expected_actions:
		menu._select_mode(mode)
		check(menu._main_play_button.text == expected_actions[mode], "explicit action for " + mode)
		var selected_count := 0
		for button in menu._mode_buttons().values():
			selected_count += 1 if button.button_pressed else 0
		check(selected_count == 1, "exactly one selected mode")
	menu.get_node("%HomeTabButton").pressed.emit()
	menu.get_node("%HeroesTabButton").pressed.emit()
	menu.get_node("%ZiloHeroButton").pressed.emit()
	check(menu._preview_character == Util.Character.Zilo, "hero browser previews selected portrait")
	menu.get_node("%SelectHeroButton").pressed.emit()
	check(MultiplayerManager.player_info.character == Util.Character.Zilo, "select hero commits the existing player selection")
	menu.get_node("%HeroesTabButton").pressed.emit()
	await capture("pregame-heroes")
	menu._show_custom_lobby_menu()
	await capture("pregame-custom-lobby")
	menu._show_local_menu()
	check(menu._local_panel.visible, "LAN panel remains reachable")
	menu.get_node("%JoinGameButton").pressed.emit()
	menu._ip_line_edit.text = "invalid-address"
	menu._port_line_edit.text = "99999"
	menu.get_node("%ConnectButton").pressed.emit()
	check(menu._ip_error_label.visible and menu._port_error_label.visible, "invalid join inputs remain visible without connecting")
	await capture("pregame-lan-join")
	menu._show_view(menu._lobbies_container)
	menu._render_lobbies("")
	check(menu._lobbies_grid.get_child_count() == 5, "empty lobby list retains four header cells")
	await capture("pregame-lobby-browser")
	menu._show_patch()
	await capture("pregame-patch-notes")
	menu._set_busy(true, "Searching…")
	check(menu._main_play_button.disabled and not menu._cancel_queue_button.disabled, "busy state gates actions but preserves cancel")
	menu._set_busy(false, "")
	menu.queue_free()
	await get_tree().process_frame
	var profile := open_screen("res://scenes/account_page.tscn")
	profile._name_line_edit.text = "123"
	profile._on_save_pressed()
	check(profile._name_error_label.visible, "profile validation remains wired")
	profile._name_line_edit.text = "Player"
	profile._name_error_label.hide()
	await capture("pregame-profile")
	profile.queue_free()
	await get_tree().process_frame
	MultiplayerManager.character_select_mode = MultiplayerManager.CharacterSelectMode.BOT
	MultiplayerManager.players.clear()
	MultiplayerManager.players[1] = {"name": "Player", "character": Util.Character.None}
	MultiplayerManager.players[MultiplayerManager.BOT_PLAYER_ID] = {"name": "Training Bot", "character": Util.Character.None}
	var selection := open_screen("res://scenes/character_select.tscn")
	check(not selection._start_button.visible, "bot cannot start with unselected slots")
	selection.get_node("%HeroRoster/Hekaset")._on_mouse_pressed()
	check(MultiplayerManager.players[1].character == Util.Character.Hekaset, "portrait card selects the player hero")
	selection.get_node("%ChooseBotButton").pressed.emit()
	selection.get_node("%HeroRoster/Zilo")._on_mouse_pressed()
	check(selection._start_button.visible, "both chosen heroes enable bot start")
	selection.get_node("%HeroRoster/Vesta")._on_mouse_pressed()
	check(MultiplayerManager.players[MultiplayerManager.BOT_PLAYER_ID].character == Util.Character.Zilo, "locked hero cannot change selection")
	var key_event := InputEventAction.new()
	key_event.action = "ui_accept"
	key_event.pressed = true
	selection.get_node("%HeroRoster/Aurora")._gui_input(key_event)
	check(MultiplayerManager.players[MultiplayerManager.BOT_PLAYER_ID].character == Util.Character.Aurora, "keyboard accept selects a hero")
	var card: Control = selection.get_node("%HeroRoster/Hekaset")
	for i in range(10):
		card._on_mouse_entered()
		card._on_mouse_exited()
	check(card.scale.is_equal_approx(Vector2.ONE), "hover does not accumulate scale or overlap neighbors")
	await capture("pregame-hero-select")
	selection.queue_free()
	await get_tree().process_frame
	MultiplayerManager.character_select_mode = MultiplayerManager.CharacterSelectMode.ONLINE
	MultiplayerManager._active_transport = "lan"
	MultiplayerManager.players.clear()
	for id in range(1, 5):
		MultiplayerManager.players[id] = {"name": "Player %d" % id, "character": Util.Character.Hekaset, "team_id": (id - 1) % 2}
	MultiplayerManager.player_info.character = Util.Character.Hekaset
	Overhaul.rules.preset = PlaytestRules.Preset.TEAM_OBJECTIVE
	selection = open_screen("res://scenes/character_select.tscn")
	check(selection._start_button.visible and not selection._preset_select.is_item_disabled(2), "LAN host can start with four selected players")
	MultiplayerManager.players[4].character = Util.Character.None
	selection._check_players_ready()
	check(not selection._start_button.visible, "missing fourth selection blocks start")
	MultiplayerManager.players[4].character = Util.Character.Hekaset
	selection._check_players_ready()
	check(selection._team_roster.text.contains("4 / 4 players"), "four-player roster remains visible")
	await capture("pregame-lan-select")
	selection.queue_free()
	await get_tree().process_frame
	print("PREGAME_SCREENS_COMPLETE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
