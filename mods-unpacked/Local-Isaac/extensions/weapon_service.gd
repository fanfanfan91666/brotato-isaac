extends "res://singletons/weapon_service.gd"

const ISAAC_STATS = preload("res://mods-unpacked/Local-Isaac/stat_rules.gd")
const ISAAC_PETS = preload("res://mods-unpacked/Local-Isaac/pet_bonus.gd")

func spawn_projectile(pos: Vector2, weapon_stats: RangedWeaponStats, direction: float, from: Node, args: WeaponServiceSpawnProjectileArgs) -> Node:
    var result = .spawn_projectile(pos, weapon_stats, direction, from, args)
    if not args.deferred:
        ISAAC_PETS.configure_projectile(result, from, args.from_player_index)
    else:
        call_deferred("isaac_configure_pet_projectile", result, from, args.from_player_index)
    return result

func isaac_configure_pet_projectile(projectile: Node, from: Node, p: int) -> void:
    if is_instance_valid(projectile) and is_instance_valid(from):
        ISAAC_PETS.configure_projectile(projectile, from, p)

func init_base_stats(from_stats: WeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service, is_structure: bool = false, is_special_spawn: bool = false, is_pet: bool = false) -> WeaponStats:
    var result = .init_base_stats(from_stats, player_index, args, is_structure, is_special_spawn, is_pet)
    if (is_pet or is_structure) and from_stats.has_meta(ISAAC_PETS.FIXED_VOLLEY_META):
        result.set_meta(ISAAC_PETS.FIXED_VOLLEY_META, true)
    result.damage = int(max(1, round(result.damage * ISAAC_STATS.soy_factor(player_index))))
    if not is_structure and not is_special_spawn and not is_pet:
        var factor = ISAAC_STATS.attack_speed_factor(player_index)
        if factor != 1.0:
            result.cooldown = int(round(result.cooldown / factor))
            result.recoil_duration /= factor
            result.set_meta("isaac_attack_speed_factor", factor)
    return result

func apply_damage_bonus(value: int, p: int) -> int:
    return int(max(1, round(.apply_damage_bonus(value, p) * ISAAC_STATS.soy_factor(p))))

func apply_structure_damage_bonus(value: int, p: int) -> int:
    return int(max(1, round(.apply_structure_damage_bonus(value, p) * ISAAC_STATS.soy_factor(p))))

func get_explosion_damage(from_stats: WeaponStats, player_index: int) -> int:
    return int(max(1, round(.get_explosion_damage(from_stats, player_index) * ISAAC_STATS.soy_factor(player_index))))

func init_ranged_stats(from_stats: RangedWeaponStats, player_index: int, is_special_spawn: bool = false, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
    var result = .init_ranged_stats(from_stats, player_index, is_special_spawn, args)
    if not is_special_spawn and from_stats.nb_projectiles > 0:
        var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
        var extra_projectiles = int(curses.sum_value("double_vision", player_index, "projectiles"))
        result.nb_projectiles += extra_projectiles
        result.set_meta(ISAAC_PETS.PLAYER_PROJECTILES_META, int(result.get_meta(ISAAC_PETS.PLAYER_PROJECTILES_META)) + extra_projectiles)
        result.knockback += int(curses.sum_value("eight_inch_nails", player_index, "knockback"))
    return result

func _set_common_ranged_stats(new_stats: RangedWeaponStats, from_stats: RangedWeaponStats, player_index: int):
    if not new_stats.has_meta(ISAAC_PETS.FIXED_VOLLEY_META):
        ._set_common_ranged_stats(new_stats, from_stats, player_index)
        # Incubus copies final weapon stats. Remember the exact contribution
        # rather than reinitializing damage or reading a later player state.
        var projectiles = int(RunData.get_player_effect(Keys.projectiles_hash, player_index))
        new_stats.set_meta(ISAAC_PETS.PLAYER_PROJECTILES_META, projectiles if from_stats.nb_projectiles > 0 else 0)
        new_stats.set_meta(ISAAC_PETS.PLAYER_SPREAD_META, projectiles * 0.1)
        return
    # Custom babies keep their own volley. Skip the player's count and its
    # accompanying spread before either is applied; all other native ranged
    # properties and pet damage/scaling still follow the ordinary calculation.
    new_stats.projectile_spread = from_stats.projectile_spread
    new_stats.nb_projectiles = from_stats.nb_projectiles
    var piercing_dmg_bonus = Utils.get_stat(Keys.piercing_damage_hash, player_index) / 100.0
    var bounce_dmg_bonus = Utils.get_stat(Keys.bounce_damage_hash, player_index) / 100.0
    new_stats.piercing = int(from_stats.piercing + RunData.get_player_effect(Keys.piercing_hash, player_index))
    new_stats.piercing_dmg_reduction = clamp(from_stats.piercing_dmg_reduction - piercing_dmg_bonus, 0, 1)
    new_stats.bounce = int(from_stats.bounce + RunData.get_player_effect(Keys.bounce_hash, player_index)) if from_stats.can_bounce else 0
    new_stats.bounce_dmg_reduction = clamp(from_stats.bounce_dmg_reduction - bounce_dmg_bonus, 0, 1)
    new_stats.projectile_scene = from_stats.projectile_scene
    if from_stats.increase_projectile_speed_with_range:
        var stat_range = Utils.get_stat(Keys.stat_range_hash, player_index)
        new_stats.projectile_speed = int(clamp(from_stats.projectile_speed + (from_stats.projectile_speed / 300.0) * stat_range, 50, 6000))
    else:
        new_stats.projectile_speed = from_stats.projectile_speed
    new_stats.set_meta(ISAAC_PETS.PLAYER_PROJECTILES_META, 0)
    new_stats.set_meta(ISAAC_PETS.PLAYER_SPREAD_META, 0.0)

func init_melee_stats(from_stats: MeleeWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> MeleeWeaponStats:
    var result = .init_melee_stats(from_stats, player_index, args)
    if result.has_meta("isaac_attack_speed_factor"):
        # Native global class constructors can retain the original script. Keep
        # every calculated field, but give this temporary result our UI method.
        var slow = load("res://mods-unpacked/Local-Isaac/world/slow_melee_stats.gd").new()
        for prop in result.get_property_list():
            if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "script":
                slow.set(prop.name, result.get(prop.name))
        for key in result.get_meta_list():
            slow.set_meta(key, result.get_meta(key))
        return slow
    return result

func explode(effect: ExplodingEffect, args: WeaponServiceExplodeArgs) -> Node:
    var result = .explode(effect, args)
    result._hitbox.set_meta("isaac_tough_love", false)
    var pet_owner = ISAAC_PETS.source_owner(args.from)
    if pet_owner < 0 and ISAAC_PETS.pet_tracking_key(args.damage_tracking_key_hash):
        pet_owner = args.from_player_index
    result._hitbox.set_meta(ISAAC_PETS.OWNER_META, pet_owner)
    if pet_owner >= 0 and result._hitbox.burning_data != null:
        result._hitbox.burning_data = result._hitbox.burning_data.duplicate()
        result._hitbox.burning_data.from = args.from
        result._hitbox.burning_data.set_meta(ISAAC_PETS.OWNER_META, pet_owner)
    result._sprite.modulate = Color(1, 1, 1, ProgressData.settings.explosion_opacity)
    return result
