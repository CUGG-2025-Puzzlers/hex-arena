extends Node

const WAITING_FOR_PLAYER = "Waiting for player..."
const SELECT_CHARACTER = "Select Character"

@onready var _local_player_name: Label = %LocalPlayerName
@onready var _local_character_art: TextureRect = %LocalCharacterArt
@onready var _local_character_name: Label = %LocalCharacterName

@onready var _remote_player_name: Label = %RemotePlayerName
@onready var _remote_character_art: TextureRect = %RemoteCharacterArt
@onready var _remote_character_name: Label = %RemoteCharacterName

@onready var _character_list_container: HBoxContainer = %CharacterList

func _ready() -> void:
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	Events.character_selected.connect(_on_character_selected)
	
	_local_player_name.text = MultiplayerManager.player_info.name
	_remote_player_name.text = WAITING_FOR_PLAYER

#region Event Listeners

# Sets the other player's label to their name
func _on_player_connected(id, info):
	_remote_player_name.text = info.name

# Sets the other player's label to the default text
func _on_player_disconnected(id):
	_remote_player_name.text = WAITING_FOR_PLAYER

# Sets this client's selected character on all clients
func _on_character_selected(character: Util.Character):
	MultiplayerManager.set_player_character(multiplayer.get_unique_id(), character)
	_set_character.rpc(character)
	
	_local_character_name.text = _get_character_name(character)
	# TODO: Set local character art here

#endregion

# Sets the sending client's selected character on this client
@rpc("any_peer", "reliable")
func _set_character(character: Util.Character):
	var sender_id = multiplayer.get_remote_sender_id()
	print("%s selected %s" % [MultiplayerManager.players[sender_id].name, Util.Character.keys()[character]])
	MultiplayerManager.set_player_character(sender_id, character)
	
	_remote_character_name.text = _get_character_name(character)
	# TODO: Set remote character art here

# Returns the name associated with the given character enum
# If the given enum is None, returns a default string
func _get_character_name(character: Util.Character):
	if character == Util.Character.None:
		return SELECT_CHARACTER
	
	return Util.Character.keys()[character]
