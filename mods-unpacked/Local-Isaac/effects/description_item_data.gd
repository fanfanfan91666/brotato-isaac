extends "res://items/global/item_data.gd"

export(Array, int) var isaac_random_points = []

func serialize() -> Dictionary:
    var result = .serialize()
    if not isaac_random_points.empty():
        result.isaac_random_points = isaac_random_points.duplicate()
    return result

func deserialize_and_merge(serialized: Dictionary) -> void:
    var current_tracking_text = tracking_text
    .deserialize_and_merge(serialized)
    # Old runs serialize presentation fields too. Keep the current label when
    # the saved item predates trackers; gameplay values still come from the save.
    if current_tracking_text != "" and current_tracking_text != "[EMPTY]":
        tracking_text = current_tracking_text
    if my_id == "item_local_isaac_double_vision":
        max_nb = 1
    if my_id == "item_local_isaac_libra":
        # Rebase saved presentation only; the acquisition conversion already
        # changed permanent stats and must never run again while loading.
        tier = 1
        value = 35
    isaac_random_points = serialized.get("isaac_random_points", []).duplicate()
    for i in isaac_random_points.size():
        isaac_random_points[i] = int(isaac_random_points[i])
    # Older saves used native NullEffect/PetEffect IDs. Upgrade only this
    # item's own presentation adapters while retaining every serialized value.
    var rules = load("res://mods-unpacked/Local-Isaac/description_rules.gd")
    for i in effects.size():
        var effect = effects[i]
        if not rules.is_custom_effect(effect):
            continue
        if not effect.get_id().begins_with("local_isaac_description_"):
            var script_path = "res://mods-unpacked/Local-Isaac/effects/description_"
            script_path += "pet_effect.gd" if effect is PetEffect else ("null_effect.gd" if effect is NullEffect else "stat_effect.gd")
            var replacement = load(script_path).new()
            replacement.deserialize_and_merge(effect.serialize())
            effects[i] = replacement
            effect = replacement
        if is_cursed and effect.curse_factor <= 0.0:
            effect.curse_factor = curse_factor
