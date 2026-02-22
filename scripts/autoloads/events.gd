extends Node

# This script should hold signals for any (and probably all) game events.
# It should provide functions to call emit those signals.
# Other scripts should call these functions instead of directly emitting from
# the signals themselves.

signal select_new_cell

signal character_selected(character: Util.Character, player_id: int)

func select_character(character: Util.Character, player_id: int):
	character_selected.emit(character, player_id)
