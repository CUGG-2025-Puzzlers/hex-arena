extends Node

var winner_name : String = ""

func load_character_select():
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

func load_arena():
	var tree = get_tree()
	tree.change_scene_to_file("res://scenes/arena.tscn")
	await tree.root.child_entered_tree
	MultiplayerManager._start_game()

func load_end_scene(winner: String) -> void:
	winner_name = winner
	get_tree().change_scene_to_file("res://scenes/EndScene.tscn") 
