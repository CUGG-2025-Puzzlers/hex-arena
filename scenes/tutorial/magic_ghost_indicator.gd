extends Area2D
class_name MagicGhostIndicator

@export var ghost_alpha := 0.28
@export var pulse_amount := 0.08
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
	modulate.a = base_alpha + pulse


func hide_ghost() -> void:
	visible = false

	neutral_sprite.visible = false
	shield_pattern.visible = false
	eye_sprite.visible = false
	arrow_particles.visible = false
	glow.visible = false


func show_neutral_ghost() -> void:
	visible = true

	neutral_sprite.visible = true
	shield_pattern.visible = false
	eye_sprite.visible = false
	arrow_particles.visible = false
	glow.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_shield_ghost() -> void:
	visible = true

	neutral_sprite.visible = false
	shield_pattern.visible = true
	eye_sprite.visible = false
	arrow_particles.visible = false
	glow.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_heavy_ghost() -> void:
	visible = true

	neutral_sprite.visible = false
	shield_pattern.visible = false
	eye_sprite.visible = true
	arrow_particles.visible = false
	glow.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)


func show_light_ghost() -> void:
	visible = true

	neutral_sprite.visible = false
	shield_pattern.visible = false
	eye_sprite.visible = false
	arrow_particles.visible = true
	glow.visible = true

	base_alpha = ghost_alpha
	modulate = Color(1, 1, 1, ghost_alpha)
