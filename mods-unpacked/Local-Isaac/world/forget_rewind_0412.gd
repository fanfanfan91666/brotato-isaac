extends Node

var shop: WeakRef

func begin() -> void:
    var owner_shop = shop.get_ref() if shop != null else null
    var rules = load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd")
    if not is_instance_valid(owner_shop) or not owner_shop.is_inside_tree() or get_tree().current_scene != owner_shop:
        RunData.set_meta(rules.PENDING_META, false)
        queue_free()
        return
    # The shop saves the consumed item and sold offer before this deferred call.
    var wave = rules.take_pending_wave()
    if wave < 1:
        queue_free()
        return
    # Match native Hourglass: replay the battle just completed with today's
    # build and money. No RunData rollback, broken item or enemy penalty.
    var shop_wave = RunData.current_wave
    RunData.current_wave = wave
    var error = get_tree().change_scene(MenuData.game_scene)
    if error != OK:
        # Keep the medicine's pending effect if the scene could not load.
        RunData.current_wave = shop_wave
        rules.state()[1] = wave
    queue_free()
