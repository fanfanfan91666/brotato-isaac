extends "res://effects/items/pet_effect.gd"

static func get_id() -> String:
    return "local_isaac_description_pet"

func get_text(player_index: int, colored: bool = true) -> String:
    return load("res://mods-unpacked/Local-Isaac/description_rules.gd").get_text(self, player_index, colored)
