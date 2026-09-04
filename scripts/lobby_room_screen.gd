extends Control

@onready var host_card = %HostPlayerCard
@onready var other_card = %OtherPlayerCard
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	host_card = MultiplayerManager.players[1].name


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
