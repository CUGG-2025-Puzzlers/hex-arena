extends Area2D
class_name MagicGhostIndicator

@export var ghost_alpha := 0.28
@export var pulse_amount := 0.22
@export var pulse_speed := 4.0

@onready var neutral_sprite: Sprite2D = $Sprite2D
@onready var shield_pattern: Polygon2D = $"Shield Pattern"
@onready var eye_sprite: Sprite2D = $EyeSprite
@onready var arrow_particles: Node2D = $ArrowParticles
@onready var glow: Sprite2D = $Glow
@onready var sparkles: CPUParticles2D = $Sparkles

var base_alpha := 0.28


func _ready() -> void:
	monitoring = false
	monitorable = false

	base_alpha = ghost_alpha
	hide_ghost()


func _process(_delta: float) -> void:
	if not visible:
		return

	var pulse := sin(Time.get_ticks_msec() / 1000.0 * pulse_speed) * pulse_amount
	modulate.a = clampf(base_alpha + pulse, 0.0, 1.0)


func hide_ghost() -> void:
	visible = false
	_hide_all_visuals()


func show_neutral_ghost() -> void:
	visible = true
	_hide_all_visuals()

	neutral_sprite.visible = true
	glow.visible = true
	sparkles.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_shield_ghost() -> void:
	visible = true
	_hide_all_visuals()

	_visualize_shield()
	glow.visible = true
	sparkles.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_heavy_ghost() -> void:
	visible = true
	_hide_all_visuals()

	eye_sprite.visible = true
	glow.visible = true
	sparkles.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_light_ghost() -> void:
	visible = true
	_hide_all_visuals()

	arrow_particles.visible = true
	glow.visible = true
	sparkles.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)

func _hide_all_visuals() -> void:
	neutral_sprite.visible = false
	shield_pattern.visible = false
	eye_sprite.visible = false
	arrow_particles.visible = false
	glow.visible = false
	sparkles.visible = false

	for polygon in find_children("Shield*", "Polygon2D"):
		var shield_polygon := polygon as Polygon2D
		if shield_polygon == null:
			continue

		shield_polygon.visible = false


func _visualize_shield() -> void:
	var bounding_box := Rect2()
	bounding_box.position = Vector2(HexCells.hex_shape[5].x, HexCells.hex_shape[0].y)
	bounding_box.size = abs(bounding_box.position) * 2.0

	for polygon in find_children("Shield*", "Polygon2D"):
		var shield_polygon := polygon as Polygon2D
		if shield_polygon == null:
			continue

		shield_polygon.polygon = HexCells.hex_shape

		if shield_polygon.texture != null and bounding_box.size.x != 0.0 and bounding_box.size.y != 0.0:
			var scale_vec: Vector2 = shield_polygon.texture.get_size() / bounding_box.size
			shield_polygon.texture_scale = Vector2.ONE * max(scale_vec.x, scale_vec.y)
			shield_polygon.texture_scale *= 2.0

		shield_polygon.visible = true

	neutral_sprite.visible = false
