extends Node

const WAITING_FOR_PLAYER = "Waiting for player..."

@onready var _local_player_name: Label = %LocalPlayerName
@onready var _remote_player_name: Label = %RemotePlayerName

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

#endregion

# Sets the sending client's selected character on this client
@rpc("any_peer", "reliable")
func _set_character(character: Util.Character):
	var sender_id = multiplayer.get_remote_sender_id()
	print("%s selected %s" % [MultiplayerManager.players[sender_id].name, Util.Character.keys()[character]])
	MultiplayerManager.set_player_character(sender_id, character)
