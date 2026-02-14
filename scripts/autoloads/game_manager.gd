extends Node

func _ready() -> void:
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)

#region Event Listeners

func _on_server_disconnected():
	pass

#endregion
