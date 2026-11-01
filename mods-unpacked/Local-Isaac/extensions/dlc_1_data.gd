extends "res://dlcs/dlc_1/dlc_1_data.gd"

func curse_item(item_data: ItemParentData, player_index: int, turn_randomization_off: bool = false, min_modifier: float = 0.0) -> ItemParentData:
    var result = .curse_item(item_data, player_index, turn_randomization_off, min_modifier)
    load("res://mods-unpacked/Local-Isaac/curse_rules.gd").stamp_native_result(item_data, result)
    if result is WeaponData and result.weapon_id == "weapon_local_isaac_broken_pickaxe":
        load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").stamp(result)
    if result is WeaponData and result.weapon_id == "weapon_local_isaac_data_hack":
        for effect in result.effects:
            if effect.key == "effect_local_isaac_data_hack":
                effect.curse_factor = result.curse_factor
    if result.my_id == "item_local_isaac_moms_knife":
        for effect in result.effects:
            if effect.key == "effect_local_isaac_moms_knife":
                effect.value = 4
    return result
