extends PanelContainer

@onready var avatar: TextureRect = $MarginContainer/VBoxContainer/Avatar
@onready var name_label: Label = $MarginContainer/VBoxContainer/InfoContainer/NameLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/InfoContainer/StatusLabel
@onready var role_label: Label = $MarginContainer/VBoxContainer/InfoContainer/RoleLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_player_info(player_name, is_ready, role, avatar_texture):
	name_label.text = str(player_name)
	status_label.text = "Ready" if is_ready else "Not Ready"
	role_label.text = str(role)
	if avatar_texture:
		avatar.texture = avatar_texture
	
	
