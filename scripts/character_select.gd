extends Node

const WAITING_FOR_PLAYER = "Waiting for player..."
const SELECT_CHARACTER = "Select Character"

@onready var _local_player_name: Label = %LocalPlayerName
@onready var _local_character_art: TextureRect = %LocalCharacterArt
@onready var _local_character_name: Label = %LocalCharacterName

@onready var _remote_player_name: Label = %RemotePlayerName
@onready var _remote_character_art: TextureRect = %RemoteCharacterArt
@onready var _remote_character_name: Label = %RemoteCharacterName

@onready var _start_button: Button = %StartButton

func _ready() -> void:
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	Events.character_selected.connect(_on_character_selected)
	_start_button.pressed.connect(_on_start_pressed)
	
	_start_button.hide()
	
	_local_player_name.text = MultiplayerManager.player_info.name
	_set_character_info(MultiplayerManager.player_info.character, true)
	
	if MultiplayerManager.players.size() > 1:
		var other_player_info = MultiplayerManager.get_other_player_info()
		_remote_player_name.text = other_player_info.name
		_set_character_info(other_player_info.character, false)
	else:
		_remote_player_name.text = WAITING_FOR_PLAYER
		_set_character_info(Util.Character.None, false)

#region Event Listeners

# Sets the other player's label to their name
func _on_player_connected(_id, info):
	_remote_player_name.text = info.name
	_set_character_info(info.character, false)

# Sets the other player's label to the default text
func _on_player_disconnected(_id):
	_remote_player_name.text = WAITING_FOR_PLAYER
	_set_character_info(Util.Character.None, false)

# Sets this client's selected character on all clients
func _on_character_selected(character: Util.Character, player_id: int):
	var sender_is_local_client = player_id == multiplayer.get_unique_id()
	_set_character_info(character, sender_is_local_client)
	_check_players_ready()

func _on_start_pressed():
	_start_game.rpc()

#endregion

# Starts the game for all clients
@rpc("call_local", "any_peer", "reliable")
func _start_game():
	SceneManager.load_arena()

# Sets the character info for the local or remote player
func _set_character_info(character: Util.Character, is_local_client: bool):
	var character_name = Util.Character.keys()[character] if character != Util.Character.None else SELECT_CHARACTER
	
	if is_local_client:
		_local_character_name.text = character_name
		_local_character_art.texture = null
	else:
		_remote_character_name.text = character_name
		_remote_character_art.texture = null

# Returns the name associated with the given character enum
# If the given enum is None, returns a default string
func _get_character_name(character: Util.Character):
	if character == Util.Character.None:
		return SELECT_CHARACTER
	
	return Util.Character.keys()[character]

# Checks if the players have both selected their characters, indicating readiness
func _check_players_ready():
	if MultiplayerManager.players.size() < 2:
		_start_button.hide()
		return
	
	for player_id in MultiplayerManager.players:
		if MultiplayerManager.players[player_id].character == Util.Character.None:
			_start_button.hide()
			return
	
	_start_button.show()
