extends Node2D

@onready var tutorial_ui: TutorialUI = $"TutorialUI"

@onready var walk_objective: Area2D = $"Walk Objective"
@onready var place_magic_objective: Area2D = $"Place Magic Objective"
@onready var light_objective: Area2D = $"Light Objective"
@onready var shield_objective: Node2D = $"Shield Objective"
@onready var final_objective: Area2D = $"Final Objective"
@onready var heavy_objectives: Array[Node2D] = [
	$"Heavy Objective",
	$"Heavy Objective2",
	$"Heavy Objective3",
]
const GUIDING_ARROWS = preload("res://scenes/tutorial/guiding_arrows.tscn")

const HEKASET_PRESET = preload(
	"res://presets/character_presets/Hekaset_stats.tres"
)

var active_arrows: Node2D = null
var arrow_target: Node2D = null
var arrow_offset := Vector2.ZERO

@onready var hex_cells: HexCells = $"Path2D"

const TOTAL_STEPS := 6

var task_text := {
	"move": {
		"step": 1,
		"title": "Collect Mana Orb",
		"description": "WASD to walk to the glowing marker.",
		"hint": ""
	},
	"create_light": {
		"step": 2,
		"title": "Create Light Arrow",
		"description": "Click on a hex to place Basic Magic.\nE to transform it into Light Arrow.",
		"hint": ""
	},
	"fire_light": {
		"step": 3,
		"title": "Fire Light Arrow",
		"description": "Aim with your mouse.\nSpace to fire.",
		"hint": ""
	},
	"create_shield": {
	"step": 4,
	"title": "Create a Shield",
	"description": "Click on a hex to place Basic Magic. \nQ to transform it.",
	"hint": ""
	},
	"break_shields": {
		"step": 5,
		"title": "Break a Shield",
		"description": "Click on a hex to place Basic Magic. \nR to transform it.",
		"hint": ""
	},
	"complete": {
		"step": 6,
		"title": "Tutorial Complete",
		"description": "Good job! Now prepare for a real duel",
		"hint": ""
	}
}

var light_count := 0

var current_step_id := ""
var current_step_started_msec := 0

var shield_objective_activated := false
var shield_objective_completed := false

var heavy_objectives_activated := false
var heavy_objective_completed := false

func _ready() -> void:
	walk_objective.completed.connect(_on_walk_objective_completed)
	place_magic_objective.completed.connect(_on_place_magic_objective_completed)

	light_objective.completed.connect(_on_light_objective_completed)
	
	shield_objective.completed.connect(_on_shield_objective_completed)
	
	final_objective.completed.connect(_on_final_objective_completed)
	
	for heavy_objective in heavy_objectives:
		heavy_objective.completed.connect(_on_heavy_objective_completed)
		
	_show_task("move")
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_global := get_global_mouse_position()
			var mouse_local := hex_cells.to_local(mouse_global)
			var cell = hex_cells.local_to_map(mouse_local)

			print("[DEBUG] clicked cell: ", cell)
			
func _on_walk_objective_completed() -> void:
	_complete_current_step()
	print("[TUTORIAL] Walk objective completed. Showing place magic objective.")

	_show_task("create_light")

	place_magic_objective.activate()


func _on_place_magic_objective_completed() -> void:
	_complete_current_step()
	print("[TUTORIAL] Light magic created. Activating light targets.")
	_show_task("fire_light")

	light_objective.activate()


func _on_light_objective_completed() -> void:
	_complete_current_step()
	print("[TUTORIAL] Activating shield objective.")
	
	_show_task("create_shield")
	shield_objective.activate()

func _on_shield_objective_completed() -> void:
	if shield_objective_completed:
		return

	shield_objective_completed = true
	_complete_current_step()

	print("[TUTORIAL] Shield block objective completed.")

	if heavy_objectives_activated:
		return

	heavy_objectives_activated = true

	_show_task("break_shields")

	for heavy_objective in heavy_objectives:
		heavy_objective.activate()

func _on_final_objective_completed() -> void:
	_complete_current_step()
	Telemetry.track("tutorial_completed")
	Telemetry.end_match({"completed": true})
	GameManager.add_xp(10)
	SceneManager.load_title()

func _on_heavy_objective_completed() -> void:
	if heavy_objective_completed:
		return
	heavy_objective_completed = true
	_complete_current_step()
	print("[TUTORIAL] Heavy objective completed.")
	_show_task("complete")
	final_objective.activate()

func spawn_tutorial_magic(
	cell: Vector2i,
	magic_type: Magic.MagicType,
	owner_id: int
) -> Magic:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		push_error("[TUTORIAL] Missing current scene.")
		return null

	var current_hex_cells := current_scene.get_node_or_null("Path2D") as HexCells

	if current_hex_cells == null:
		push_error("[TUTORIAL] Missing HexCells / Path2D.")
		return null

	if not HexCells.cell_dict.has(cell):
		push_error(
			"[TUTORIAL] Cannot spawn magic outside the grid at cell %s."
			% cell
		)
		return null

	if HEKASET_PRESET == null:
		push_error("[TUTORIAL] Hekaset preset failed to load.")
		return null

	if not HEKASET_PRESET.magics.has(magic_type):
		push_error(
			"[TUTORIAL] Hekaset preset has no magic for type %s."
			% Magic.MagicType.keys()[magic_type]
		)
		return null

	# Do not use `as MagicStats` here. The dictionary is already typed.
	var magic_stats = HEKASET_PRESET.magics.get(magic_type)

	if magic_stats == null:
		push_error(
			"[TUTORIAL] Missing magic stats for type %s."
			% Magic.MagicType.keys()[magic_type]
		)
		return null

	if magic_stats.scene == null:
		push_error(
			"[TUTORIAL] Magic stats has no scene for type %s."
			% Magic.MagicType.keys()[magic_type]
		)
		return null

	var magic := magic_stats.scene.instantiate() as Magic

	if magic == null:
		push_error(
			"[TUTORIAL] Scene did not instantiate as Magic for type %s."
			% Magic.MagicType.keys()[magic_type]
		)
		return null

	magic.place_instance_for_player(
		cell,
		null,
		magic_stats
	)

	# place_instance_for_player sets -1 because there is no Player owner.
	# Override it with the tutorial's synthetic enemy ID.
	magic.player_id = owner_id

	return magic

func _complete_current_step() -> void:
	if current_step_id.is_empty() or current_step_started_msec <= 0:
		return

	var task = task_text[current_step_id]
	Telemetry.track("tutorial_step_completed", {
		"step_id": current_step_id,
		"step_number": task["step"],
		"duration_seconds": maxf(
			0.0,
			float(Time.get_ticks_msec() - current_step_started_msec) / 1000.0
		),
	})

	current_step_id = ""
	current_step_started_msec = 0


func _show_task(id: String) -> void:
	current_step_id = id
	current_step_started_msec = Time.get_ticks_msec()

	var task = task_text[id]
	Telemetry.track("tutorial_step_shown", {
		"step_id": id,
		"step_number": task["step"],
	})

	tutorial_ui.set_progress(task["step"], TOTAL_STEPS)
	tutorial_ui.set_task(
		task["title"],
		task["description"],
		task["hint"]
	)
