extends Reference

static func has(name: String, p: int) -> bool:
    return p >= 0 and p < RunData.get_player_count() and RunData.get_nb_item(Keys.generate_hash("item_local_isaac_" + name), p) > 0

static func config(name: String, p: int) -> Dictionary:
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var factor = 0.0
    if p >= 0 and p < RunData.get_player_count():
        for item in RunData.get_player_items(p):
            if item.my_id == "item_local_isaac_" + name:
                factor = max(factor, curses.item_factor(item))
    return curses.params(name, factor)
