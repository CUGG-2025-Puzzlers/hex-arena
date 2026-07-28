extends Node2D

## Isolated visual prototype for fire-direction readability.
## Remove this autoload and the res://debug folder to uninstall it.

@export_category("Availability")
@export var feature_enabled: bool = true
@export var debug_menu_enabled: bool = false
@export var debug_menu_starts_visible: bool = false

@export_category("Indicator Defaults")
@export var leading_edge_glow_enabled: bool = true
@export var chevrons_enabled: bool = true
@export var cursor_reticle_enabled: bool = true
@export var short_paths_enabled: bool = false
@export var destination_hex_enabled: bool = false
@export var particle_drift_enabled: bool = false

@export_category("Display")
@export_range(0.5, 2.0, 0.05)
var indicator_scale: float = 1.0

@export_range(0.5, 2.0, 0.05)
var cursor_reticle_scale: float = 2.0

const MENU_KEY := KEY_QUOTELEFT
const FEATURE_KEY := KEY_F9

const TEAL := Color("#8BE3DE")
const TEAL_BRIGHT := Color("#D3FFFC")
const TEAL_DARK := Color("#24B7B0")
const MUTED := Color("#9DAAB5")
const INVALID := Color("#D94A57")
const PANEL_TEXT := Color("#F5F8FA")

const INDICATOR_PROPERTIES := [
	"leading_edge_glow_enabled",
	"chevrons_enabled",
	"cursor_reticle_enabled",
	"short_paths_enabled",
	"destination_hex_enabled",
	"particle_drift_enabled",
]

var _menu_requested_visible: bool = true
var _menu_panel: PanelContainer
var _status_label: Label
var _feature_check: CheckButton
var _indicator_checks: Dictionary = {}

var _gameplay_active: bool = false
var _local_player: Player
var _fireable_magic: Array[Magic] = []
var _aim_direction: Vector2 = Vector2.ZERO
var _aim_valid: bool = false
var _cursor_world: Vector2 = Vector2.ZERO
var _animation_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4090
	z_as_relative = false
	_menu_requested_visible = debug_menu_starts_visible

	_build_debug_menu()
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	_animation_time += delta
	_refresh_gameplay_state()
	_refresh_debug_menu()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var key := key_event.keycode
	if key == KEY_NONE:
		key = key_event.physical_keycode

	if key == MENU_KEY and debug_menu_enabled:
		_menu_requested_visible = not _menu_requested_visible
		_refresh_debug_menu()
		get_viewport().set_input_as_handled()
	elif key == FEATURE_KEY:
		feature_enabled = not feature_enabled
		_sync_menu_controls()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not feature_enabled or not _gameplay_active:
		return

	if _fireable_magic.is_empty():
		return

	var scale := _screen_space_scale() * indicator_scale

	if not _aim_valid:
		if cursor_reticle_enabled:
			_draw_invalid_cursor(
				_screen_space_scale() * cursor_reticle_scale
			)
		return

	for magic_instance: Magic in _fireable_magic:
		if not is_instance_valid(magic_instance):
			continue

		var radius := _get_magic_radius(magic_instance)

		if leading_edge_glow_enabled:
			_draw_leading_edge_glow(
				magic_instance.global_position,
				radius,
				scale
			)

		if chevrons_enabled:
			_draw_chevron(
				magic_instance.global_position,
				radius,
				scale
			)

		if short_paths_enabled:
			_draw_short_path(
				magic_instance.global_position,
				radius,
				scale
			)

		if destination_hex_enabled:
			_draw_destination_hex(magic_instance, scale)

		if particle_drift_enabled:
			_draw_particle_drift(
				magic_instance.global_position,
				radius,
				scale
			)

	if cursor_reticle_enabled:
		_draw_cursor_reticle(
			_screen_space_scale() * cursor_reticle_scale
		)


func _refresh_gameplay_state() -> void:
	_gameplay_active = false
	_local_player = null
	_fireable_magic.clear()
	_aim_direction = Vector2.ZERO
	_aim_valid = false

	if not is_instance_valid(HexCells.player_unique_instance):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var players_node := current_scene.find_child(
		"Players",
		true,
		false
	)
	if players_node == null:
		return

	var local_id := multiplayer.get_unique_id()
	for child: Node in players_node.get_children():
		if child is Player and (child as Player).player_id == local_id:
			_local_player = child as Player
			break

	if not is_instance_valid(_local_player):
		return

	_gameplay_active = true
	_cursor_world = _local_player.get_global_mouse_position()
	_collect_fireable_magic(local_id)

	var direction_vector := (
		HexCells.map_to_local(HexCells.curr_cell)
		- HexCells.map_to_local(Magic.last_placed_cell)
	)
	_aim_valid = not direction_vector.is_zero_approx()
	if _aim_valid:
		_aim_direction = direction_vector.normalized()


func _collect_fireable_magic(local_id: int) -> void:
	for node: Node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var magic_instance := node as Magic
		if (
			magic_instance.player_id != local_id
			or magic_instance.rolling
			or magic_instance.is_queued_for_deletion()
		):
			continue

		if magic_instance is MagicTidebladeOrb:
			var tideblade := magic_instance as MagicTidebladeOrb
			if tideblade.can_activate_water_attack():
				_fireable_magic.append(magic_instance)
		elif magic_instance is MagicPressureLance:
			var pressure_lance := magic_instance as MagicPressureLance
			if pressure_lance.can_activate_water_attack():
				_fireable_magic.append(magic_instance)
		elif magic_instance is MagicRootHand:
			_fireable_magic.append(magic_instance)
		elif magic_instance is MagicBurst:
			_fireable_magic.append(magic_instance)
		elif (
			magic_instance.state in [
				Magic.MagicType.LIGHT,
				Magic.MagicType.HEAVY,
				Magic.MagicType.PASSIVE,
			]
			and magic_instance.roll_speed > 0.0
		):
			_fireable_magic.append(magic_instance)


func _screen_space_scale() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 1.0

	var zoom_amount := maxf(
		(absf(camera.zoom.x) + absf(camera.zoom.y)) * 0.5,
		0.01
	)
	return 1.0 / zoom_amount


func _get_magic_radius(magic_instance: Magic) -> float:
	var collision := magic_instance.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		var global_scale := magic_instance.global_transform.get_scale()
		return circle.radius * maxf(
			absf(global_scale.x),
			absf(global_scale.y)
		)

	return 24.0


func _draw_leading_edge_glow(
	center: Vector2,
	radius: float,
	scale: float
) -> void:
	var angle := _aim_direction.angle()
	var start_angle := angle - 0.72
	var end_angle := angle + 0.72

	draw_arc(
		center,
		radius + 6.0 * scale,
		start_angle,
		end_angle,
		18,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.18),
		9.0 * scale,
		true
	)
	draw_arc(
		center,
		radius + 5.0 * scale,
		start_angle,
		end_angle,
		18,
		Color(TEAL_BRIGHT.r, TEAL_BRIGHT.g, TEAL_BRIGHT.b, 0.9),
		2.2 * scale,
		true
	)


func _draw_chevron(
	center: Vector2,
	radius: float,
	scale: float
) -> void:
	var forward := _aim_direction
	var side := Vector2(-forward.y, forward.x)
	var chevron_center := center + forward * (
		radius + 13.0 * scale
	)

	var tip := chevron_center + forward * 8.0 * scale
	var left := (
		chevron_center
		- forward * 5.0 * scale
		+ side * 6.0 * scale
	)
	var right := (
		chevron_center
		- forward * 5.0 * scale
		- side * 6.0 * scale
	)

	draw_colored_polygon(
		PackedVector2Array([tip, left, right]),
		Color(TEAL_BRIGHT.r, TEAL_BRIGHT.g, TEAL_BRIGHT.b, 0.92)
	)
	draw_polyline(
		PackedVector2Array([left, tip, right]),
		TEAL_DARK,
		1.2 * scale,
		true
	)


func _draw_short_path(
	center: Vector2,
	radius: float,
	scale: float
) -> void:
	var start := center + _aim_direction * (
		radius + 8.0 * scale
	)
	var path_length := maxf(
		HexCells.hex_width * 0.72,
		58.0 * scale
	)
	var dash_length := 11.0 * scale
	var gap_length := 7.0 * scale
	var travelled := 0.0

	while travelled < path_length:
		var segment_end := minf(
			travelled + dash_length,
			path_length
		)
		draw_line(
			start + _aim_direction * travelled,
			start + _aim_direction * segment_end,
			Color(TEAL.r, TEAL.g, TEAL.b, 0.62),
			2.0 * scale,
			true
		)
		travelled += dash_length + gap_length

	var end := start + _aim_direction * path_length
	var side := Vector2(-_aim_direction.y, _aim_direction.x)
	draw_polyline(
		PackedVector2Array([
			end - _aim_direction * 7.0 * scale
				+ side * 4.0 * scale,
			end,
			end - _aim_direction * 7.0 * scale
				- side * 4.0 * scale,
		]),
		Color(TEAL_BRIGHT.r, TEAL_BRIGHT.g, TEAL_BRIGHT.b, 0.72),
		1.8 * scale,
		true
	)


func _draw_destination_hex(
	magic_instance: Magic,
	scale: float
) -> void:
	var destination := _get_forward_neighbor(
		magic_instance.self_cell
	)
	var points_array: Array = HexCells.get_hex_points_around(
		destination
	)
	var points := PackedVector2Array()

	for point: Vector2 in points_array:
		points.append(point)

	if points.size() < 2:
		return

	draw_polyline(
		points,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.76),
		2.2 * scale,
		true
	)

	var center := HexCells.map_to_local(destination)
	draw_circle(
		center,
		3.0 * scale,
		Color(TEAL_BRIGHT.r, TEAL_BRIGHT.g, TEAL_BRIGHT.b, 0.72)
	)


func _get_forward_neighbor(origin: Vector2i) -> Vector2i:
	var best_cell := origin
	var best_dot := -1.0e20
	var origin_position := HexCells.map_to_local(origin)

	for neighbor: Vector2i in HexCells.get_surrounding_cells(origin):
		var offset := (
			HexCells.map_to_local(neighbor)
			- origin_position
		)
		if offset.is_zero_approx():
			continue

		var score := offset.normalized().dot(_aim_direction)
		if score > best_dot:
			best_dot = score
			best_cell = neighbor

	return best_cell


func _draw_particle_drift(
	center: Vector2,
	radius: float,
	scale: float
) -> void:
	var side := Vector2(-_aim_direction.y, _aim_direction.x)

	for index in range(4):
		var phase := fposmod(
			_animation_time * 0.8 + float(index) * 0.25,
			1.0
		)
		var lateral := sin(
			_animation_time * 2.4 + float(index) * 1.9
		) * radius * 0.32
		var start := (
			center
			- _aim_direction * radius * 0.72
			+ side * lateral
		)
		var particle_position := (
			start
			+ _aim_direction * radius * 1.55 * phase
		)
		var alpha := sin(phase * PI) * 0.72

		draw_circle(
			particle_position,
			(1.8 + float(index % 2)) * scale,
			Color(
				TEAL_BRIGHT.r,
				TEAL_BRIGHT.g,
				TEAL_BRIGHT.b,
				alpha
			)
		)


func _draw_cursor_reticle(scale: float) -> void:
	var center := (
		_cursor_world
		+ _aim_direction * 28.0 * scale
	)
	var side := Vector2(-_aim_direction.y, _aim_direction.x)

	draw_arc(
		center,
		13.0 * scale,
		0.0,
		TAU,
		24,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.72),
		1.6 * scale,
		true
	)
	draw_line(
		center - _aim_direction * 8.0 * scale,
		center + _aim_direction * 10.0 * scale,
		TEAL_BRIGHT,
		2.0 * scale,
		true
	)

	var tip := center + _aim_direction * 12.0 * scale
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tip - _aim_direction * 7.0 * scale
				+ side * 4.0 * scale,
			tip - _aim_direction * 7.0 * scale
				- side * 4.0 * scale,
		]),
		TEAL_BRIGHT
	)

	var badge_center := center + side * 19.0 * scale
	draw_circle(
		badge_center,
		9.0 * scale,
		Color(0.047, 0.067, 0.09, 0.94)
	)
	draw_arc(
		badge_center,
		9.0 * scale,
		0.0,
		TAU,
		18,
		TEAL,
		1.4 * scale,
		true
	)

	var font := ThemeDB.fallback_font
	var font_size := maxi(8, roundi(12.0 * scale))
	var count_text := str(_fireable_magic.size())
	var text_size := font.get_string_size(
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	)
	draw_string(
		font,
		badge_center - text_size * 0.5
			+ Vector2(0.0, text_size.y * 0.78),
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PANEL_TEXT
	)


func _draw_invalid_cursor(scale: float) -> void:
	var center := _cursor_world + Vector2(22.0, -22.0) * scale

	draw_arc(
		center,
		11.0 * scale,
		0.0,
		TAU,
		20,
		Color(INVALID.r, INVALID.g, INVALID.b, 0.84),
		1.8 * scale,
		true
	)
	draw_line(
		center + Vector2(-6.0, -6.0) * scale,
		center + Vector2(6.0, 6.0) * scale,
		INVALID,
		2.0 * scale,
		true
	)
	draw_line(
		center + Vector2(-6.0, 6.0) * scale,
		center + Vector2(6.0, -6.0) * scale,
		INVALID,
		2.0 * scale,
		true
	)


func _build_debug_menu() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "DebugMenuLayer"
	canvas_layer.layer = 100
	add_child(canvas_layer)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "FireDirectionDebugMenu"
	_menu_panel.anchor_left = 1.0
	_menu_panel.anchor_right = 1.0
	_menu_panel.offset_left = -370.0
	_menu_panel.offset_top = 110.0
	_menu_panel.offset_right = -24.0
	_menu_panel.offset_bottom = 690.0
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_layer.add_child(_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_menu_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "FIRE DIRECTION DEBUG"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var hint := Label.new()
	hint.text = "` hides this menu  •  F9 toggles indicators"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = MUTED
	column.add_child(hint)

	column.add_child(HSeparator.new())

	_feature_check = _make_check(
		"Indicators enabled",
		"feature_enabled"
	)
	column.add_child(_feature_check)

	var heading := Label.new()
	heading.text = "INDICATORS"
	heading.modulate = TEAL
	column.add_child(heading)

	column.add_child(_make_check(
		"Leading-edge glow",
		"leading_edge_glow_enabled"
	))
	column.add_child(_make_check(
		"Directional chevrons",
		"chevrons_enabled"
	))
	column.add_child(_make_check(
		"Cursor reticle + count",
		"cursor_reticle_enabled"
	))
	column.add_child(_make_check(
		"Short projected paths",
		"short_paths_enabled"
	))
	column.add_child(_make_check(
		"Destination hex outlines",
		"destination_hex_enabled"
	))
	column.add_child(_make_check(
		"Directional particle drift",
		"particle_drift_enabled"
	))

	column.add_child(HSeparator.new())

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	column.add_child(preset_row)

	var recommended_button := Button.new()
	recommended_button.text = "RECOMMENDED"
	recommended_button.pressed.connect(_apply_recommended_preset)
	preset_row.add_child(recommended_button)

	var all_on_button := Button.new()
	all_on_button.text = "ALL ON"
	all_on_button.pressed.connect(_set_all_indicators.bind(true))
	preset_row.add_child(all_on_button)

	var all_off_button := Button.new()
	all_off_button.text = "ALL OFF"
	all_off_button.pressed.connect(_set_all_indicators.bind(false))
	preset_row.add_child(all_off_button)

	var scale_label := Label.new()
	scale_label.text = "World indicator size"
	column.add_child(scale_label)

	var scale_slider := HSlider.new()
	scale_slider.min_value = 0.5
	scale_slider.max_value = 2.0
	scale_slider.step = 0.05
	scale_slider.value = indicator_scale
	scale_slider.value_changed.connect(_on_scale_changed)
	column.add_child(scale_slider)

	var cursor_scale_label := Label.new()
	cursor_scale_label.text = "Cursor reticle size"
	column.add_child(cursor_scale_label)

	var cursor_scale_slider := HSlider.new()
	cursor_scale_slider.min_value = 0.5
	cursor_scale_slider.max_value = 2.0
	cursor_scale_slider.step = 0.05
	cursor_scale_slider.value = cursor_reticle_scale
	cursor_scale_slider.value_changed.connect(
		_on_cursor_scale_changed
	)
	column.add_child(cursor_scale_slider)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = MUTED
	column.add_child(_status_label)

	var hide_button := Button.new()
	hide_button.text = "HIDE MENU (`)"
	hide_button.pressed.connect(_hide_debug_menu)
	column.add_child(hide_button)


func _make_check(
	label_text: String,
	property_name: String
) -> CheckButton:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = bool(get(property_name))
	check.toggled.connect(
		_on_property_toggled.bind(property_name)
	)
	_indicator_checks[property_name] = check
	return check


func _on_property_toggled(
	enabled: bool,
	property_name: String
) -> void:
	set(property_name, enabled)
	queue_redraw()


func _on_scale_changed(value: float) -> void:
	indicator_scale = float(value)
	queue_redraw()


func _on_cursor_scale_changed(value: float) -> void:
	cursor_reticle_scale = float(value)
	queue_redraw()


func _apply_recommended_preset() -> void:
	leading_edge_glow_enabled = true
	chevrons_enabled = true
	cursor_reticle_enabled = true
	short_paths_enabled = false
	destination_hex_enabled = false
	particle_drift_enabled = false
	indicator_scale = 1.0
	cursor_reticle_scale = 2.0
	_sync_menu_controls()
	queue_redraw()


func _set_all_indicators(enabled: bool) -> void:
	for property_name in INDICATOR_PROPERTIES:
		set(property_name, enabled)

	_sync_menu_controls()
	queue_redraw()


func _sync_menu_controls() -> void:
	if is_instance_valid(_feature_check):
		_feature_check.set_pressed_no_signal(feature_enabled)

	for property_name: String in _indicator_checks:
		var check := _indicator_checks[property_name] as CheckButton
		if is_instance_valid(check):
			check.set_pressed_no_signal(
				bool(get(property_name))
			)


func _hide_debug_menu() -> void:
	_menu_requested_visible = false
	_refresh_debug_menu()


func _refresh_debug_menu() -> void:
	if not is_instance_valid(_menu_panel):
		return

	_menu_panel.visible = (
		debug_menu_enabled
		and _menu_requested_visible
		and _gameplay_active
	)

	if not is_instance_valid(_status_label):
		return

	if not _gameplay_active:
		_status_label.text = "Waiting for an arena scene."
	elif _fireable_magic.is_empty():
		_status_label.text = "Fireable magic: 0"
	elif not _aim_valid:
		_status_label.text = (
			"Fireable magic: %d\n"
			+ "Aim direction: invalid"
		) % _fireable_magic.size()
	else:
		_status_label.text = (
			"Fireable magic: %d\n"
			+ "Direction: (%.2f, %.2f)"
		) % [
			_fireable_magic.size(),
			_aim_direction.x,
			_aim_direction.y,
		]
