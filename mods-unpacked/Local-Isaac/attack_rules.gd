extends Reference

const META = "isaac_attack_proc"
const TOUGH = "isaac_tough_love"
const PROJECTILE = "res://mods-unpacked/Local-Isaac/world/proc_projectile.tscn"
const BLAST = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const IPECAC_PROGRESS = "local_isaac_ipecac_weapon_progress"
const IPECAC_ATTACKS = 10
const TRACKING = "item_local_isaac_ipecac"

static func count(name: String, p: int) -> int:
    return preload("res://mods-unpacked/Local-Isaac/stat_rules.gd").count(name, p)

static func probability(kind: String, luck: float, copies: int, factor: float = 0.0) -> float:
    var triggers = preload("res://mods-unpacked/Local-Isaac/trigger_rules.gd")
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    if kind == "nail":
        var nail = curses.params("eight_inch_nails", factor)
        return triggers.probability(nail.base_chance, nail.luck_chance, luck, copies)
    if kind == "tough":
        var tough = curses.params("tough_love", factor)
        return triggers.probability(tough.base_chance, tough.luck_chance, luck, copies)
    return 0.0

# Rows follow the owned WeaponData slots, not weapon type or scene instances.
# Each row is [numeric weapon ID hash, attack count]. Native save restoration
# recursively hashes string keys AND string values, so keep both fields numeric.
# RunData's weapon mutations move/remove these rows.
static func ipecac_rows(p: int) -> Array:
    var effects = RunData.get_player_effects(p)
    var key = Keys.generate_hash(IPECAC_PROGRESS)
    if not effects.has(key) or not effects[key] is Array:
        effects[key] = []
    var rows = effects[key]
    var owned = RunData.get_player_weapons(p)
    while rows.size() < owned.size():
        rows.append([owned[rows.size()].my_id_hash, 0])
    rows.resize(owned.size())
    for slot in owned.size():
        if not rows[slot] is Array or rows[slot].size() != 2 or int(rows[slot][0]) != owned[slot].my_id_hash:
            rows[slot] = [owned[slot].my_id_hash, 0]
    return rows

static func advance_ipecac(weapon: Weapon) -> bool:
    if count("ipecac", weapon.player_index) == 0:
        return false
    var rows = ipecac_rows(weapon.player_index)
    var slot = weapon.weapon_pos
    if slot < 0 or slot >= rows.size():
        return false
    var row = rows[slot]
    row[1] = (int(row[1]) + 1) % ipecac_attacks(weapon.player_index)
    return row[1] == 0

static func ipecac_attacks(p: int) -> int:
    return int(load("res://mods-unpacked/Local-Isaac/curse_rules.gd").min_value("ipecac", p, "attacks", IPECAC_ATTACKS))

static func roll(weapon: Weapon) -> Dictionary:
    var result = {"nail": false, "ipecac": false, "tough": false}
    if not weapon._parent is Player:
        return result
    var p = weapon.player_index
    var luck = Utils.get_stat(Keys.stat_luck_hash, p)
    var copies = count("eight_inch_nails", p) if weapon.stats is RangedWeaponStats else 0
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    if copies > 0:
        result.nail = Utils._rng.randf() < curses.owned_probability("eight_inch_nails", p, luck)
    result.ipecac = advance_ipecac(weapon)
    copies = count("tough_love", p)
    if copies > 0:
        result.tough = Utils._rng.randf() < curses.owned_probability("tough_love", p, luck)
    return result

static func any_proc(state: Dictionary) -> bool:
    return state.nail or state.ipecac or state.tough

static func projectile_stats(weapon: Weapon, base: WeaponStats, state: Dictionary) -> RangedWeaponStats:
    var result: RangedWeaponStats
    if base is RangedWeaponStats:
        result = base.duplicate()
    else:
        result = RangedWeaponStats.new()
        result.damage = base.damage
        result.crit_chance = base.crit_chance
        result.crit_damage = base.crit_damage
        result.accuracy = base.accuracy
        result.max_range = max(400, base.max_range)
        result.projectile_speed = 800
        result.knockback = base.knockback
        result.scaling_stats = base.scaling_stats.duplicate(true)
    result.projectile_scene = load(PROJECTILE)
    if state.tough:
        result.damage *= 2
    result.set_meta(META, attack_data(weapon, base, state))
    return result

static func burn_damage(p: int, coefficient: float) -> int:
    var raw = int(round(max(0.0, Utils.get_stat(Keys.stat_elemental_damage_hash, p) * coefficient)))
    return WeaponService.apply_damage_bonus(raw, p) if raw > 0 else 0

static func attack_data(weapon: Weapon, base: WeaponStats, state: Dictionary) -> Dictionary:
    var data = state.duplicate(true)
    data.player = weapon.player_index
    data.crit_chance = base.crit_chance
    data.crit_damage = base.crit_damage
    if state.ipecac:
        var explosion_stats = WeaponStats.new()
        explosion_stats.damage = weapon.stats.damage
        explosion_stats.scaling_stats = [[Keys.stat_ranged_damage_hash, 0.5], [Keys.stat_melee_damage_hash, 0.5], [Keys.stat_elemental_damage_hash, 1.0]]
        data.explosion_damage = WeaponService.get_explosion_damage(explosion_stats, weapon.player_index) * (2 if state.tough else 1)
        data.burn_damage = burn_damage(weapon.player_index, 0.5)
        data.burn_scaling = 0.5
        data.poison = true
        data.status = "IsaacIpecacPoison"
        data.tracking = Keys.generate_hash(TRACKING)
    return data

static func explode_at(pos: Vector2, data: Dictionary) -> Node:
    var game = Utils.get_scene_node()
    if not game is Main or game._cleaning_up or not RunData.wave_in_progress:
        return null
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = pos
    args.damage = int(data.explosion_damage)
    args.accuracy = 1.0
    args.crit_chance = data.crit_chance
    args.crit_damage = data.crit_damage
    args.from_player_index = int(data.player)
    args.damage_tracking_key_hash = int(data.get("tracking", Keys.empty_hash))
    var explosion = WeaponService.explode(BLAST, args)
    explosion._hitbox.set_meta(TOUGH, false)
    explosion._sprite.modulate = Color(0.4, 1.0, 0.25, ProgressData.settings.explosion_opacity)
    explosion.connect("hit_something", game, "isaac_ipecac_explosion_hit", [data.duplicate(true)])
    return explosion
