extends "res://singletons/item_service.gd"

var isaac_content

func init_dlc_content() -> void:
    .init_dlc_content()
    isaac_register_content()

func isaac_register_content() -> bool:
    if isaac_content != null:
        return false
    isaac_content = load("res://mods-unpacked/Local-Isaac/NewContentData.tres")
    return isaac_content != null and isaac_content.register()

func init_unlocked_pool() -> void:
    .init_unlocked_pool()
    # Bombs have their own extra drop roll and must never replace fruit or crates.
    var bomb_id = Keys.generate_hash("consumable_local_isaac_bomb")
    var rooms = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    for tier in _tiers_data:
        var pool = tier[TierData.CONSUMABLES]
        for i in range(pool.size() - 1, -1, -1):
            if pool[i].my_id_hash == bomb_id:
                pool.remove(i)
        # Both ordinary item indexes feed shops, crates and random item drops.
        # Keep the resources registered/unlocked for the independent room pool.
        for pool_kind in [TierData.ITEMS, TierData.ALL_ITEMS]:
            var item_pool = tier[pool_kind]
            for i in range(item_pool.size() - 1, -1, -1):
                if rooms.is_room_only(item_pool[i]):
                    item_pool.remove(i)
