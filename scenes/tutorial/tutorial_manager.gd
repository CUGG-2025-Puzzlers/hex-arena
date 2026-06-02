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
	print("[TUTORIAL] Walk objective completed. Showing place magic objective.")

	_show_task("create_light")

	place_magic_objective.activate()


func _on_place_magic_objective_completed() -> void:
	print("[TUTORIAL] Light magic created. Activating light targets.")
	_show_task("fire_light")

	light_objective.activate()


func _on_light_objective_completed() -> void:
	print("[TUTORIAL] Activating shield objective.")
	
	_show_task("create_shield")
	shield_objective.activate()

func _on_shield_objective_completed() -> void:
	if shield_objective_completed:
		return

	shield_objective_completed = true

	print("[TUTORIAL] Shield block objective completed.")

	if heavy_objectives_activated:
		return

	heavy_objectives_activated = true

	_show_task("break_shields")

	for heavy_objective in heavy_objectives:
		heavy_objective.activate()

func _on_final_objective_completed() -> void:
	GameManager.add_xp(10)
	SceneManager.load_title()

func _on_heavy_objective_completed() -> void:
	if heavy_objective_completed:
		return
	heavy_objective_completed = true
	print("[TUTORIAL] Heavy objective completed.")
	_show_task("complete")
	final_objective.activate()

func spawn_tutorial_magic(
	cell: Vector2i,
	magic_type: Magic.MagicType,
	owner_id: int
) -> Magic:
	var hex_cells := get_tree().current_scene.get_node("Path2D") as HexCells
	if hex_cells == null:
		push_error("Missing HexCells / Path2D")
		return null

	var magic := preload("res://scenes/magic.tscn").instantiate() as Magic

	magic.self_cell = cell
	magic.position = hex_cells.map_to_local(cell)
	magic.add_to_group("magic")

	# Add first, because Magic._ready() needs self_cell and scene access.
	hex_cells.add_child(magic, true)

	# Set owner after add_child because Magic.gd has @onready player_id.
	magic.player_id = owner_id

	# Apply final type after owner is correct.
	magic.change_state(magic_type)

	return magic

func _show_task(id: String) -> void:
	var task = task_text[id]

	tutorial_ui.set_progress(task["step"], TOTAL_STEPS)
	tutorial_ui.set_task(
		task["title"],
		task["description"],
		task["hint"]
	)
