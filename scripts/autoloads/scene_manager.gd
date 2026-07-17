extends Node

var winner_name : String = ""

func load_character_select():
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")

func load_title_screen():
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func load_account_page():
	get_tree().change_scene_to_file("res://scenes/account_page.tscn")

func load_arena():
	var tree = get_tree()
	tree.change_scene_to_file("res://scenes/arena.tscn")
	await tree.root.child_entered_tree
	await get_tree().process_frame
	await get_tree().process_frame

	MultiplayerManager._start_game()

func load_bot_match():
	var tree = get_tree()
	tree.change_scene_to_file("res://scenes/arena.tscn")

	await tree.root.child_entered_tree
	await get_tree().process_frame
	await get_tree().process_frame

	MultiplayerManager._start_bot_match()

func load_tutorial():
	var tree = get_tree()
	tree.change_scene_to_file("res://scenes/tutorial/tutorial_arena.tscn")
	await tree.root.child_entered_tree
	MultiplayerManager._start_tutorial()

func load_end_scene(winner: String) -> void:
	winner_name = winner
	get_tree().call_deferred("change_scene_to_file","res://scenes/EndScene.tscn") 

func load_title():
	var tree = get_tree()
	tree.call_deferred("change_scene_to_file","res://scenes/title_screen.tscn")
