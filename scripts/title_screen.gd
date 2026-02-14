extends Node

#region Setup

func _ready() -> void:
	%HostGameButton.pressed.connect(_on_host_game)
	%JoinGameButton.pressed.connect(_on_join_game)
	%ConnectButton.pressed.connect(_on_connect)
	%BackButton.pressed.connect(_on_back)

#endregion

#region Button Callbacks

func _on_host_game():
	pass

func _on_join_game():
	pass

func _on_connect():
	pass

func _on_back():
	pass

#endregion
