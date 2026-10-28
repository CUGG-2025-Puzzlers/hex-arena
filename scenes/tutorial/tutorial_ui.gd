extends CanvasLayer
class_name TutorialUI

@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar

@onready var task_title: Label = %TaskTitle
@onready var task_description: Label = %TaskDescription
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	visible = true
	hint_label.visible = false


func set_progress(current_step: int, total_steps: int) -> void:
	progress_label.text = "Tutorial %d / %d" % [current_step, total_steps]

	progress_bar.min_value = 0
	progress_bar.max_value = total_steps
	progress_bar.value = current_step


func set_task(title: String, description: String, hint: String = "") -> void:
	task_title.text = title
	task_description.text = description
	hint_label.text = hint
	hint_label.visible = hint != ""


func clear_task() -> void:
	task_title.text = ""
	task_description.text = ""
	hint_label.text = ""
	hint_label.visible = false
