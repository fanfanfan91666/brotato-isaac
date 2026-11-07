extends Reference

const CHARACTER_ID = "character_local_isaac"
const D6_ID = "item_local_isaac_d6"
const COUPONS_KEY = "local_isaac_d6_free_rerolls"
const BASE_CHANCE = 0.5

static func common_starting_weapons() -> Array:
    # The encyclopedia includes owned but inactive DLC. Starting weapons use
    # the same base and active update sets as the native run's unlocked pool.
    var active_weapons = ItemService.base_game_item_set.weapons.duplicate()
    for update in ItemService.update_data_list:
        if update != null and update.item_set != null and ProgressData.has_item_set(update.id):
            active_weapons.append_array(update.item_set.weapons)
    var weapons = []
    var seen = {}
    for weapon in active_weapons:
        if not weapon is WeaponData or weapon.tier != Tier.COMMON:
            continue
        if not weapon.type in [WeaponType.MELEE, WeaponType.RANGED]:
            continue
        if seen.has(weapon.my_id):
            continue
        seen[weapon.my_id] = true
        weapons.append(weapon)
    return ItemService.get_ordered_starting_weapons(weapons)

static func coupons(player_index: int) -> int:
    return int(RunData.get_player_effects(player_index).get(Keys.generate_hash(COUPONS_KEY), 0))

static func chance(player_index: int) -> float:
    return clamp(load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("d6", player_index, "chance", BASE_CHANCE), 0.0, 1.0)

static func complete_reroll(player_index: int, used_coupon: bool) -> void:
    var effects = RunData.get_player_effects(player_index)
    var coupon_key = Keys.generate_hash(COUPONS_KEY)
    if used_coupon:
        effects[coupon_key] = max(0, coupons(player_index) - 1)
    if RunData.get_nb_item(Keys.generate_hash(D6_ID), player_index) <= 0:
        return
    # Rolling on every refresh, including a refresh paid with a coupon, lets
    # free rerolls chain naturally. Coupons are unspent rewards; the tracked
    # value counts every coupon ever earned by this player's D6.
    if Utils._rng.randf() >= chance(player_index):
        return
    effects[coupon_key] = coupons(player_index) + 1
    RunData.add_tracked_value(player_index, Keys.generate_hash(D6_ID), 1)
