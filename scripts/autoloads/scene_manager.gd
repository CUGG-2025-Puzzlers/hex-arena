extends Node

var winner_name: String = ""


func load_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func load_title_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func load_account_page() -> void:
	get_tree().change_scene_to_file("res://scenes/account_page.tscn")


func load_arena() -> void:
	var tree := get_tree()
	tree.change_scene_to_file("res://scenes/arena.tscn")
	await tree.scene_changed
	await tree.process_frame
	MultiplayerManager._start_game()


func load_bot_match() -> void:
	var tree := get_tree()
	tree.change_scene_to_file("res://scenes/arena.tscn")
	await tree.scene_changed
	await tree.process_frame
	MultiplayerManager._start_bot_match()


func load_tutorial() -> void:
	var tree := get_tree()
	tree.change_scene_to_file("res://scenes/tutorial/tutorial_arena.tscn")
	await tree.scene_changed
	await tree.process_frame
	MultiplayerManager._start_tutorial()


func load_end_scene(winner: String) -> void:
	winner_name = winner
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/EndScene.tscn"
	)


func load_title() -> void:
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/title_screen.tscn"
	)
