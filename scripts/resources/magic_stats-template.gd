@tool

extends Resource
class_name MagicStats

@export var type: Magic.MagicType = Magic.MagicType.NONE

@export var magic_name : String = ""

@export var cost: float = 0.

@export var scene: PackedScene = null

@export var health: float = 0.
@export var damage: float = 0.
@export var speed: float = 0.

@export var collide_w_own: bool = false

@export var transform_dict : Dictionary[Magic.MagicType, Resource] = {
	Magic.MagicType.NEUTRAL: null,
	Magic.MagicType.LIGHT: null,
	Magic.MagicType.HEAVY: null,
	Magic.MagicType.PASSIVE: null
}:
	set(val):
		for key in val:
			var value = val[key]
			if value and not (value is MagicStats):
				if Engine.is_editor_hint():
					var dialog = AcceptDialog.new()
					dialog.dialog_text = "Bad Value Assignment!\nThis slot only accepts MagicStats resources."
					EditorInterface.get_base_control().add_child(dialog)
					dialog.popup_centered()
				val[key] = null
		transform_dict = val
