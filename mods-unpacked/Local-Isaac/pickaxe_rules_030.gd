extends Reference

const ID = "weapon_local_isaac_broken_pickaxe"
const BOMBS = preload("res://mods-unpacked/Local-Isaac/bomb_rules.gd")
const PLANK = preload("res://weapons/melee/plank/1/plank_exploding_effect.tres")

static func raw_stats(tier: int, factor: float = 1.0) -> WeaponStats:
    var raw = WeaponStats.new()
    raw.damage = int(ceil([10, 15, 20, 30][clamp(tier, 0, 3)] * factor))
    raw.scaling_stats = [[Keys.stat_melee_damage_hash, 0.5 * factor], [Keys.stat_elemental_damage_hash, 0.5 * factor], [Keys.stat_engineering_hash, 0.5 * factor]]
    return raw

static func stats_factor(stats: WeaponStats, cursed: bool) -> float:
    if not cursed:
        return 1.0
    var melee = WeaponService.find_scaling_stat(Keys.stat_melee_damage_hash, stats.scaling_stats)
    var armor = WeaponService.find_scaling_stat(Keys.stat_armor_hash, stats.scaling_stats)
    # Saved placeholder pickaxes used 100% melee and had no armor coefficient.
    var base = 0.8 if armor != null else 1.0
    return max(1.0, float(melee[1]) / base) if melee != null else 1.0

static func stamp(data: Resource) -> void:
    if not data is WeaponData or data.weapon_id != ID:
        return
    for effect in data.effects:
        if effect.key == "effect_local_isaac_pickaxe_bomb":
            # Reuse native persistent fields; no new Effect type or JSON strings
            # in Player.effects, and description matches the weapon's actual roll.
            effect.custom_key = "local_isaac_pickaxe_bomb_tier_" + str(data.tier + 1)
            effect.custom_key_hash = Keys.generate_hash(effect.custom_key)
            effect.curse_factor = stats_factor(data.stats, data.is_cursed) - 1.0

static func chance(weapon: Node) -> float:
    return clamp(load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").value(weapon, "pickaxe_bomb", [10, 15, 20, 25][clamp(weapon.tier, 0, 3)]) / 100.0, 0.0, 1.0)

static func prepare(weapon: Node) -> Dictionary:
    if weapon.weapon_id != ID or BOMBS.count(weapon.player_index) <= 0 or not Utils.get_chance_success(chance(weapon)):
        return {}
    var game = Utils.get_scene_node()
    if not game is Main or game._cleaning_up or not RunData.wave_in_progress:
        return {}
    var raw = raw_stats(weapon.tier, stats_factor(weapon.stats, weapon.is_cursed))
    return {"owner": weapon.player_index, "damage": WeaponService.get_explosion_damage(raw, weapon.player_index), "crit_chance": weapon.current_stats.crit_chance, "crit_damage": weapon.current_stats.crit_damage, "raw_scaling": raw.scaling_stats, "game": weakref(game)}

static func explode_at(pos: Vector2, source: Node, data: Dictionary) -> Node:
    var game = Utils.get_scene_node()
    if not is_instance_valid(source) or not game is Main or game._cleaning_up or not RunData.wave_in_progress or data.empty():
        return null
    if data.has("game") and data.game.get_ref() != game:
        return null
    var p = int(data.owner)
    if p < 0 or p >= RunData.get_player_count() or BOMBS.count(p) <= 0:
        return null
    # Shared inventory is checked at the actual hit: simultaneous weapons can
    # spend the final bomb only once, and a missed swing never loses a bomb.
    BOMBS.change_count(p, -1)
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = pos
    args.damage = int(data.damage)
    args.scaling_stats = data.raw_scaling
    args.accuracy = 1.0
    args.crit_chance = data.crit_chance
    args.crit_damage = data.crit_damage
    args.from_player_index = p
    args.from = source
    var copied = source.weapon_pos < 0
    if copied:
        args.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_incubus")
    var result = WeaponService.explode(PLANK, args)
    if not copied:
        result.connect("hit_something", source, "on_weapon_hit_something", [result._hitbox])
    result.connect("killed_something", source, "on_killed_something", [result._hitbox])
    return result
