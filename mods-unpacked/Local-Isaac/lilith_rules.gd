extends Reference

const CHARACTER_ID = "character_local_lilith"
const INCUBUS_ID = "item_local_isaac_incubus"
const BEST_FRIENDS_ID = "item_local_isaac_best_friends_forever"

static func is_lilith(player_index: int) -> bool:
    var character = RunData.get_player_character(player_index)
    return character != null and character.my_id == CHARACTER_ID

static func common_starting_pets(player_index: int) -> Array:
    # ItemService is the active content catalog, including native and mod pets.
    # The character's explicit choice grants access regardless of unlock state,
    # just like Isaac's list of all common starting weapons.
    var pets = []
    var seen = {}
    for item in ItemService.items:
        if not item is ItemData or item is WeaponData or item is CharacterData:
            continue
        if item.tier != Tier.COMMON or not item.can_be_looted or item.max_nb == 0:
            continue
        if seen.has(item.my_id) or item.my_id in [INCUBUS_ID, BEST_FRIENDS_ID]:
            continue
        if item.max_nb > 0 and RunData.get_nb_item(item.my_id_hash, player_index) >= item.max_nb:
            continue
        for effect in item.effects:
            if effect is PetEffect and effect.scene != null:
                pets.append(item)
                seen[item.my_id] = true
                break
    return ItemService.get_ordered_starting_items(pets)
