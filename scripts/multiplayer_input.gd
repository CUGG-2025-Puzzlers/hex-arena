class_name MultiplayerInput
extends Node

var direction: Vector2

func _ready() -> void:
	direction = Input.get_vector("left", "right", "up", "down")

func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
