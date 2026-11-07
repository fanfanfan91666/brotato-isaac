extends Reference

const STAT = "stat_local_isaac_bombs"
const CONSUMABLE = "consumable_local_isaac_bomb"
const BASE_DROP_CHANCE = 0.01
const TREE_DROP_MULTIPLIER = 5.0
const AUTO_RANGE = 500.0
const AUTO_COOLDOWN = 0.8
const DAMAGE = 100
const EXPLOSION_SCALE = 1.2
const ROCK_LAYER_BIT = 20
const ROCKS = "local_isaac_rocks"
const BOGO_ID = "item_local_isaac_bomb_bogo"
const MR_BOMB_ID = "item_local_isaac_mr_bomb"
const KNIFE_ID = "item_local_isaac_moms_knife"
const KNIFE_PROGRESS = "local_isaac_knife_progress"
const SCENERY_RATE = 0.7
const KNIFE_ATTACKS = 12
const KNIFE_COOLDOWN_MS = 300
const PICKUP_ATTRACT_RANGE = 100.0
const PICKUP_AMOUNT_META = "isaac_bomb_pickup_amount"
const PICKUP_BOGO_OWNER_META = "isaac_bomb_bogo_owner"

static func rock_bomb_amount() -> int:
    var roll = Utils.randi_range(1, 10)
    return 0 if roll <= 5 else (1 if roll <= 9 else 2)

static func pickup_amount(player_index: int) -> int:
    return int(load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("bomb_bogo", player_index, "amount", 1.0))

static func knife_multiplier(player_index: int) -> int:
    if RunData.get_nb_item(Keys.generate_hash(KNIFE_ID), player_index) == 0:
        return 0
    var result = 0
    for item in RunData.players_data[player_index].items:
        if item.my_id == KNIFE_ID:
            result = max(result, 4 if item.is_cursed else 2)
    return result

static func count(player_index: int) -> int:
    return int(RunData.get_player_effects(player_index).get(Keys.generate_hash(STAT), 0))

static func change_count(player_index: int, amount: int) -> void:
    var key = Keys.generate_hash(STAT)
    var effects = RunData.get_player_effects(player_index)
    var previous = int(effects.get(key, 0))
    var updated = int(max(0, previous + amount))
    if updated == previous:
        return
    effects[key] = updated
    RunData._are_player_stats_dirty[player_index] = true
    Utils.reset_stat_cache(player_index)

static func drop_chance(is_tree: bool = false) -> float:
    var luck_factor = clamp(1.0 + Utils.average_all_player_stats(Keys.stat_luck_hash) / 100.0, 0.0, 2.0)
    return min(1.0, BASE_DROP_CHANCE * luck_factor * (TREE_DROP_MULTIPLIER if is_tree else 1.0))

static func explosion_radius(player_index: int) -> float:
    return 147.34 * max(0.1, EXPLOSION_SCALE * (1.0 + Utils.get_stat(Keys.explosion_size_hash, player_index) / 100.0))
