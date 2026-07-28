extends Node

const WAITING_FOR_PLAYER := "Waiting for player..."
const SELECT_CHARACTER := "Select Character"

@onready var _local_player_name: Label = %LocalPlayerName
@onready var _local_character_art: TextureRect = %LocalCharacterArt
@onready var _local_character_name: Label = %LocalCharacterName
@onready var _remote_player_name: Label = %RemotePlayerName
@onready var _remote_character_art: TextureRect = %RemoteCharacterArt
@onready var _remote_character_name: Label = %RemoteCharacterName

@onready var _copy_external_ip_button: Button = %CopyExternalIPButton
@onready var _copy_internal_ip_button: Button = %CopyInternalIPButton
@onready var _port_forwarding_label: Label = %PortForwardingLabel
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton
@onready var _selection_target_container: HBoxContainer = %SelectionTargetContainer
@onready var _choose_player_button: Button = %ChoosePlayerButton
@onready var _choose_bot_button: Button = %ChooseBotButton
@onready var _selection_instruction: Label = %SelectionInstruction

@export var texture_list: Array[Texture2D]

var _bot_mode := false
var _selection_target_id := 1


func _ready() -> void:
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	Events.character_selected.connect(_on_character_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_choose_player_button.pressed.connect(_select_player_slot)
	_choose_bot_button.pressed.connect(_select_bot_slot)

	_bot_mode = (
		MultiplayerManager.character_select_mode
		== MultiplayerManager.CharacterSelectMode.BOT
	)
	_start_button.hide()
	_copy_internal_ip_button.hide()
	_copy_external_ip_button.hide()
	_port_forwarding_label.hide()

	if _bot_mode:
		_setup_bot_mode()
	else:
		_setup_online_mode()

	_check_players_ready()
	Telemetry.track("character_select_viewed", {
		"mode": "bot" if _bot_mode else "online",
	})


func handle_character_card_pressed(character: Util.Character) -> void:
	if _bot_mode:
		MultiplayerManager.set_bot_match_character(
			_selection_target_id,
			character
		)
	else:
		MultiplayerManager.select_character(character)


func _setup_bot_mode() -> void:
	_selection_target_container.show()
	_select_player_slot()

	var local_info: Dictionary = MultiplayerManager.players.get(1, {})
	var bot_info: Dictionary = MultiplayerManager.players.get(
		MultiplayerManager.BOT_PLAYER_ID,
		{}
	)
	_local_player_name.text = str(local_info.get("name", "Player"))
	_remote_player_name.text = str(bot_info.get("name", "Training Bot"))
	_set_character_info(
		local_info.get("character", Util.Character.None),
		true
	)
	_set_character_info(
		bot_info.get("character", Util.Character.None),
		false
	)


func _setup_online_mode() -> void:
	_selection_target_container.hide()
	_selection_instruction.text = "Choose your mage"

	if multiplayer.is_server():
		_copy_internal_ip_button.show()
		_copy_internal_ip_button.pressed.connect(_on_copy_internal_ip_pressed)
		if MultiplayerManager.external_ip:
			_copy_external_ip_button.show()
			_copy_external_ip_button.pressed.connect(_on_copy_external_ip_pressed)
		else:
			_port_forwarding_label.show()

	_local_player_name.text = MultiplayerManager.player_info.name
	_set_character_info(MultiplayerManager.player_info.character, true)

	if MultiplayerManager.players.size() > 1:
		var other_player_info = MultiplayerManager.get_other_player_info()
		_remote_player_name.text = other_player_info.name
		_set_character_info(other_player_info.character, false)
	else:
		_remote_player_name.text = WAITING_FOR_PLAYER
		_set_character_info(Util.Character.None, false)


func _select_player_slot() -> void:
	_selection_target_id = 1
	_choose_player_button.disabled = true
	_choose_bot_button.disabled = false
	_selection_instruction.text = "Selecting your character"


func _select_bot_slot() -> void:
	_selection_target_id = MultiplayerManager.BOT_PLAYER_ID
	_choose_player_button.disabled = false
	_choose_bot_button.disabled = true
	_selection_instruction.text = "Selecting the training bot"


func _on_player_connected(_id, info) -> void:
	if _bot_mode:
		return

	_remote_player_name.text = info.name
	_set_character_info(info.character, false)

	# A player may arrive with a character already selected on the main menu.
	# Re-check readiness here instead of waiting for another selection event.
	_check_players_ready()


func _on_player_disconnected(_id) -> void:
	if _bot_mode:
		return

	_remote_player_name.text = WAITING_FOR_PLAYER
	_set_character_info(Util.Character.None, false)
	_check_players_ready()


func _on_character_selected(
	character: Util.Character,
	player_id: int
) -> void:
	var is_local_slot := (
		player_id == 1
		if _bot_mode
		else player_id == multiplayer.get_unique_id()
	)
	_set_character_info(character, is_local_slot)
	_check_players_ready()


func _on_copy_external_ip_pressed() -> void:
	if MultiplayerManager.external_ip:
		DisplayServer.clipboard_set(MultiplayerManager.external_ip)


func _on_copy_internal_ip_pressed() -> void:
	DisplayServer.clipboard_set(MultiplayerManager.local_ip)


func _on_start_pressed() -> void:
	if _bot_mode:
		Telemetry.track("bot_match_confirmed")
		SceneManager.load_bot_match()
	else:
		_start_game.rpc()


func _on_back_pressed() -> void:
	_back_button.disabled = true

	# Wait for the lobby operation before changing scenes. This prevents an
	# abandoned advertised lobby when the final member returns to the menu.
	if not _bot_mode:
		await LobbyMatchmakingManager.cleanup_lobby()

	MultiplayerManager.reset_character_select_mode()
	SceneManager.load_title()


@rpc("call_local", "any_peer", "reliable")
func _start_game() -> void:
	SceneManager.load_arena()


func _set_character_info(
	character: Util.Character,
	is_local_client: bool
) -> void:
	var character_name := (
		Util.get_character_display_name(character)
		if character != Util.Character.None
		else SELECT_CHARACTER
	)
	var character_texture: Texture2D = null
	var character_index := int(character)
	if character_index >= 0 and character_index < texture_list.size():
		character_texture = texture_list[character_index]

	if is_local_client:
		_local_character_name.text = character_name
		_local_character_art.texture = character_texture
	else:
		_remote_character_name.text = character_name
		_remote_character_art.texture = character_texture


func _check_players_ready() -> void:
	if MultiplayerManager.players.size() < 2:
		_start_button.hide()
		return

	for player_id in MultiplayerManager.players:
		if (
			MultiplayerManager.players[player_id].character
			== Util.Character.None
		):
			_start_button.hide()
			return

	_start_button.show()
