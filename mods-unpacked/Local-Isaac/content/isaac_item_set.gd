extends ItemSetData

export(Array, Resource) var sets = []
export(Array, Resource) var consumables = []
export(Array, Script) var effects = []
export(Array, Translation) var translations = []
export(Dictionary) var tracked_items = {}

func register() -> bool:
    var base_set = ItemService.base_game_item_set
    if base_set.items.has(items[0]):
        return false

    # Keep the mod alongside the base game regardless of DLC switches or the
    # list of active updates stored by a previous run.
    for data in items + weapons + characters + consumables + sets:
        data._generate_hashes()
    for weapon in weapons:
        if weapon.upgrades_into != null:
            weapon.upgrades_into.previous_upgrade = weapon
    for stat in stats:
        stat.generate_hashes()
    base_set.items.append_array(items)
    base_set.weapons.append_array(weapons)
    base_set.characters.append_array(characters)
    # Native tooltips look here. These display stats stay out of the random
    # combat stat selection used by effects such as swapping min/max stats.
    base_set.stats.append_array(stats)
    ItemService.invalidate_items_cache()
    ItemService.invalidate_weapons_cache()
    ItemService.invalidate_characters_cache()

    ItemService.consumables.append_array(consumables)
    ItemService.sets.append_array(sets)
    ItemService.effects.append_array(effects)
    for translation in translations:
        TranslationServer.add_translation(translation)

    var tracked = Utils.convert_dictionary_to_hash(tracked_items)
    RunData.init_tracked_items.merge(tracked)
    for counters in RunData.tracked_item_effects:
        counters.merge(tracked)
    return true
