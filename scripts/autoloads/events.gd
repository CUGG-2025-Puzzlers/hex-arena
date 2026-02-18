extends Node

# This script should hold signals for any (and probably all) game events.
# It should provide functions to call emit those signals.
# Other scripts should call these functions instead of directly emitting from
# the signals themselves.

signal select_new_cell

signal character_selected(character: Util.Character)
signal character_deselected()

func select_character(character: Util.Character):
	character_selected.emit(character)

func deselect_character():
	character_deselected.emit()
