extends Reference

const IDS = ["brother_bobby", "sister_maggy", "ghost_baby", "rainbow_baby", "seraphim", "little_steven", "demon_baby"]
const PROJECTILE = "res://mods-unpacked/Local-Isaac/world/baby_projectile.tscn"
const BLAST = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const PET_BONUS = preload("res://mods-unpacked/Local-Isaac/pet_bonus.gd")

static func choose_mode() -> int:
    return Utils.randi_range(0, 4)

static func base_stats(kind: int, mode: int = 3) -> RangedWeaponStats:
    var result = RangedWeaponStats.new()
    result.set_meta(PET_BONUS.FIXED_VOLLEY_META, true)
    result.cooldown = 48
    result.damage = [5, 10, 5, 0, 20, 10, 10][kind]
    result.scaling_stats = [[Keys.stat_ranged_damage_hash, [0.5, 0.3, 0.1, 0.0, 1.0, 0.5, 0.5][kind]]]
    if kind == 6:
        result.scaling_stats.append([Keys.stat_engineering_hash, 0.5])
    if kind == 3:
        result.damage = [5, 15, 15, 10, 5][mode]
        result.scaling_stats = [[Keys.stat_ranged_damage_hash, 0.1]] if mode == 4 else []
    result.piercing = 1 if kind == 4 else (2 if kind == 5 else 0)
    if kind == 5:
        result.speed_percent_modifier = -50
    result.crit_chance = 0
    result.crit_damage = 2.0
    result.max_range = 500
    result.projectile_speed = 900
    result.projectile_scene = load(PROJECTILE)
    result.knockback = 5
    result.accuracy = 1.0
    return result

static func init_stats(kind: int, p: int, mode: int = 3, factor: float = 0.0) -> RangedWeaponStats:
    var args = WeaponServiceInitStatsArgs.new()
    if kind == 3 and mode == 1:
        args.effects = [BLAST]
    var base = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").boost_pet_stats(base_stats(kind, mode), factor)
    return WeaponService.init_ranged_pet_stats(base, p, false, args)

static func burn_damage(p: int, factor: float = 0.0) -> int:
    var coefficient = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("rainbow_baby", factor).burn_coefficient
    var scaling = [[Keys.stat_elemental_damage_hash, coefficient]]
    scaling = WeaponService._apply_beast_master_weapon_scaling_stat_effects(scaling, p)
    scaling = WeaponService._apply_weapon_scaling_stat_effects(scaling, p)
    var raw = int(round(max(0.0, WeaponService.sum_scaling_stat_values(scaling, p))))
    return WeaponService.apply_damage_bonus(raw, p) if raw > 0 else 0

static func burn_data(p: int, factor: float = 0.0) -> Dictionary:
    var coefficient = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("rainbow_baby", factor).burn_coefficient
    return {"player": p, "burn_damage": burn_damage(p, factor), "burn_scaling": coefficient, "duration": 3, "status": "IsaacBabyBurn", "pet_damage": true, "poison": false}

static func apply_burn(target: Node, data: Dictionary) -> void:
    var game = Utils.get_scene_node()
    if game is Main and not game._cleaning_up and RunData.wave_in_progress:
        game.isaac_ipecac_explosion_hit(target, 0, data)

static func explode_at(pos: Vector2, data: Dictionary) -> Node:
    var game = Utils.get_scene_node()
    if not game is Main or game._cleaning_up or not RunData.wave_in_progress:
        return null
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = pos
    args.damage = int(data.damage)
    args.damage_tracking_key_hash = int(data.get("tracking", Keys.empty_hash))
    args.accuracy = 1.0
    args.from_player_index = int(data.player)
    args.crit_chance = data.crit_chance
    args.crit_damage = data.crit_damage
    var explosion = WeaponService.explode(BLAST, args)
    return explosion
