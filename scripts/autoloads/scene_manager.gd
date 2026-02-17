extends Node

func load_character_select():
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

func load_arena():
	get_tree().change_scene_to_file("res://scenes/arena.tscn")
