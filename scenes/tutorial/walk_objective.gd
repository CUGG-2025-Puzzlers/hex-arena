extends Area2D

signal completed

@export var arrow_count := 3
@export var arrow_scale := 0.75
@export var arrow_spacing := 64.0
@export var arrow_start_offset := Vector2(0, 105)

@export var arrow_color := Color(0.35, 0.85, 1.0, 1.0)
@export var arrow_glow_color := Color(0.1, 0.65, 1.0, 1.0)

@export var arrow_base_alpha := 0.22
@export var arrow_lit_alpha := 1.0

# Timing:
# Each arrow starts after arrow_pulse_interval.
# Each arrow stays lit for arrow_pulse_duration.
# If duration > interval, the pulses overlap.
@export var arrow_pulse_interval = 0.16
@export var arrow_pulse_duration = 0.26
@export var arrow_cycle_pause = 2.8

# Movement popup.
@export var movement_popup_delay := 5.0
@export var movement_popup_offset := Vector2(-95, -145)
@export_multiline var movement_popup_text := "Use WASD to move\n\n   W\nA  S  D"

@onready var player_id: int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var complete := false

var movement_input_detected := false
var movement_popup: PanelContainer = null


func _ready() -> void:
	print("[WALK OBJECTIVE] spawned")
	
	_create_movement_popup()
	_start_movement_popup_timer()

	queue_redraw()


func _process(delta: float) -> void:
	if not movement_input_detected and _is_movement_pressed():
		movement_input_detected = true
		_hide_movement_popup()

	queue_redraw()

func _create_movement_popup() -> void:
	movement_popup = PanelContainer.new()
	movement_popup.name = "MovementPopup"
	movement_popup.visible = false
	movement_popup.position = movement_popup_offset
	movement_popup.z_index = 100
	movement_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.08, 0.12, 0.88)
	panel_style.border_color = Color(0.35, 0.85, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	movement_popup.add_theme_stylebox_override("panel", panel_style)

	var label := Label.new()
	label.text = movement_popup_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.85, 0.97, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.18, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)

	movement_popup.add_child(label)
	add_child(movement_popup)


func _start_movement_popup_timer() -> void:
	await get_tree().create_timer(movement_popup_delay).timeout

	if complete:
		return

	if movement_input_detected:
		return

	_show_movement_popup()


func _show_movement_popup() -> void:
	if movement_popup == null:
		return

	movement_popup.visible = true
	movement_popup.modulate.a = 0.0
	movement_popup.scale = Vector2.ONE * 0.92

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(movement_popup, "modulate:a", 1.0, 0.18)
	tween.tween_property(movement_popup, "scale", Vector2.ONE, 0.18)


func _hide_movement_popup() -> void:
	if movement_popup == null:
		return

	movement_popup.visible = false


func _is_movement_pressed() -> bool:
	if Input.is_key_pressed(KEY_W):
		return true
	if Input.is_key_pressed(KEY_A):
		return true
	if Input.is_key_pressed(KEY_S):
		return true
	if Input.is_key_pressed(KEY_D):
		return true

	if InputMap.has_action("move_up") and Input.is_action_pressed("move_up"):
		return true
	if InputMap.has_action("move_down") and Input.is_action_pressed("move_down"):
		return true
	if InputMap.has_action("move_left") and Input.is_action_pressed("move_left"):
		return true
	if InputMap.has_action("move_right") and Input.is_action_pressed("move_right"):
		return true

	return false

func _on_area_entered(area: Area2D) -> void:
	if complete:
		return

	print("[WALK OBJECTIVE] touched by area=", area.name)

	var player := _find_player_node(area)

	if player == null:
		print("[WALK OBJECTIVE] not a player")
		return

	var entered_player_id = player.get("player_id")

	if entered_player_id != null and int(entered_player_id) == player_id:
		print("[WALK OBJECTIVE] objective complete")
		_complete_objective()


func _find_player_node(node: Node) -> Node:
	var current := node

	while current != null:
		if current.is_in_group("player"):
			return current

		current = current.get_parent()

	return null


func _complete_objective() -> void:
	if complete:
		return

	complete = true

	print("[WALK OBJECTIVE] objective complete")

	collision_shape.set_deferred("disabled", true)
	collision_shape.set_deferred("monitoring", false)
	collision_shape.set_deferred("monitorable", false)

	_hide_movement_popup()
	
	_play_complete_vfx()

	completed.emit()


func _play_complete_vfx() -> void:
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE * 1.0
	
	particles.modulate.a = 0.0
	particles.visible = true
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "arrow_fade_alpha", 0.0, 0.35)

	tween.tween_property(glow_sprite, "modulate:a", 0.6, 0.12)
	tween.tween_property(glow_sprite, "scale", Vector2.ONE * 1.8, 0.35)

	tween.tween_property(particles, "modulate:a", 0.6, 0.12)

	tween.chain()
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(particles, "modulate:a", 0.0, 0.12)

	tween.finished.connect(queue_free)
