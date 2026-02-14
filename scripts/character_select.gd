extends Node

const WAITING_FOR_PLAYER = "Waiting for player..."

@onready var _local_player_name: Label = %LocalPlayerName
@onready var _remote_player_name: Label = %RemotePlayerName

func _ready() -> void:
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	
	_local_player_name.text = MultiplayerManager.player_info.name
	_remote_player_name.text = WAITING_FOR_PLAYER

#region Event Listeners

func _on_player_connected(id, info):
	_remote_player_name.text = info.name

func _on_player_disconnected(id):
	_remote_player_name.text = WAITING_FOR_PLAYER

#endregion
