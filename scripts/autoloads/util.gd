extends Node

# This script should hold utility functions and enums that should be accessible
# from any script at any time.

enum Character {
	None,
	Zilo,
	Vesta,
	Hekaset,
	WaterOrbA,
	WaterOrbB,
	Aurora,
}

enum Ability {
	None,
	Flash,
	Dash,
	Ghost,
	Teleport,
}


func get_character_display_name(character: Character) -> String:
	match character:
		Character.WaterOrbA:
			return "Aqua A"
		Character.WaterOrbB:
			return "Aqua B"
		Character.Aurora:
			return "Aurora"
		Character.None:
			return "None"
		_:
			return Character.keys()[character]
