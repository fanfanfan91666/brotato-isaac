extends "res://ui/menus/run/weapon_selection.gd"

const ISAAC_RULES = preload("res://mods-unpacked/Local-Isaac/isaac_rules.gd")
const LILITH_RULES = preload("res://mods-unpacked/Local-Isaac/lilith_rules.gd")
const NEUTRAL_CHARACTERS = ["character_local_magdalene", "character_local_cain", "character_local_blue_baby", "character_local_judas", "character_local_keeper", "character_local_forgotten"]

func isaac_add_custom_starters(character: CharacterData, player_index: int) -> void:
    if not RunData.player_has_weapon_slots(player_index) or character.starting_weapons.empty():
        return
    var seen = {}
    for weapon in character.starting_weapons:
        seen[weapon.my_id] = true
    for weapon in ItemService.weapons:
        if weapon.tier == Tier.COMMON and weapon.my_id.begins_with("weapon_local_isaac_") and not seen.has(weapon.my_id):
            if character.my_id == "character_local_forgotten" and weapon.type != WeaponType.MELEE:
                continue
            character.starting_weapons.append(weapon)
            seen[weapon.my_id] = true

func _get_all_possible_elements(player_index: int) -> Array:
    var character = RunData.get_player_character(player_index)
    if character.my_id in NEUTRAL_CHARACTERS:
        # Native DLC activation can add choices after CharacterData is loaded.
        # Borrow the current ordinary list without copying any stat effects.
        character.starting_weapons = ItemService.get_element_safe(ItemService.characters, "character_well_rounded").starting_weapons.duplicate()
        isaac_add_custom_starters(character, player_index)
        if character.my_id == "character_local_forgotten":
            var melee_weapons = []
            for weapon in character.starting_weapons:
                if weapon.type == WeaponType.MELEE:
                    melee_weapons.append(weapon)
            character.starting_weapons = melee_weapons
        return ._get_all_possible_elements(player_index)
    if character.my_id == LILITH_RULES.CHARACTER_ID:
        character.starting_weapons = []
        character.starting_items = LILITH_RULES.common_starting_pets(player_index)
        return character.starting_items.duplicate()
    if character.my_id != ISAAC_RULES.CHARACTER_ID:
        isaac_add_custom_starters(character, player_index)
        return ._get_all_possible_elements(player_index)
    character.starting_weapons = ISAAC_RULES.common_starting_weapons()
    return character.starting_weapons.duplicate()

func _get_unlocked_elements(player_index: int) -> Array:
    if LILITH_RULES.is_lilith(player_index):
        var pet_ids = []
        for pet in _get_all_possible_elements(player_index):
            pet_ids.append(pet.my_id_hash)
        return pet_ids
    if RunData.get_player_character(player_index).my_id != ISAAC_RULES.CHARACTER_ID:
        return ._get_unlocked_elements(player_index)
    var unlocked = []
    for weapon in _get_all_possible_elements(player_index):
        unlocked.append(weapon.my_id_hash)
    return unlocked
