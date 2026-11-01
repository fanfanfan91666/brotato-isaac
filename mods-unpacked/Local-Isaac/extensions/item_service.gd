extends "res://singletons/item_service.gd"

func init_unlocked_pool() -> void:
    .init_unlocked_pool()
    # Bombs have their own extra drop roll and must never replace fruit or crates.
    var bomb_id = Keys.generate_hash("consumable_local_isaac_bomb")
    for tier in _tiers_data:
        var pool = tier[TierData.CONSUMABLES]
        for i in range(pool.size() - 1, -1, -1):
            if pool[i].my_id_hash == bomb_id:
                pool.remove(i)
