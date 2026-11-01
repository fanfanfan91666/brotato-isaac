extends Reference

const TRACKING = "item_local_isaac_incubus"
const PET_BONUS = preload("res://mods-unpacked/Local-Isaac/pet_bonus.gd")

static func sync(weapon: Weapon, at_wave_begin: bool = true) -> void:
    var source = weapon.source_weapon
    if not is_instance_valid(source):
        return
    # These are already final player stats. Reinitializing them as pet or weapon
    # stats would apply Soy Milk, Polyphemus and other multipliers twice.
    var player_projectiles = int(source.current_stats.get_meta(PET_BONUS.PLAYER_PROJECTILES_META)) if source.current_stats.has_meta(PET_BONUS.PLAYER_PROJECTILES_META) else 0
    var player_spread = float(source.current_stats.get_meta(PET_BONUS.PLAYER_SPREAD_META)) if source.current_stats.has_meta(PET_BONUS.PLAYER_SPREAD_META) else 0.0
    weapon.current_stats = copy_stats(source.current_stats, weapon, player_projectiles, player_spread)
    weapon._stats_every_x_shots = {}
    for key in source._stats_every_x_shots:
        # Subtract the ordinary volley contribution, preserving the source
        # weapon's intrinsic extra projectiles on every-Xth-shot variants.
        weapon._stats_every_x_shots[key] = copy_stats(source._stats_every_x_shots[key], weapon, player_projectiles, player_spread)
    weapon._hitbox.projectiles_on_hit = source._hitbox.projectiles_on_hit.duplicate()
    var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(weapon.current_stats)
    weapon._hitbox.set_damage(weapon.current_stats.damage, args)
    weapon._hitbox.effect_scale = weapon.current_stats.effect_scale
    weapon._hitbox.speed_percent_modifier = weapon.current_stats.speed_percent_modifier
    weapon._hitbox.effects = weapon.effects
    weapon._hitbox.from = weapon
    weapon._hitbox.damage_tracking_key_hash = Keys.generate_hash(TRACKING)
    if at_wave_begin:
        weapon._current_cooldown = weapon.get_next_cooldown(true)
    weapon.reset_cooldown()
    weapon._range_shape.shape.radius = weapon.current_stats.max_range + Weapon.DETECTION_RANGE
    if load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").eligible(weapon):
        load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").sync(weapon, true)

static func copy_stats(source: WeaponStats, weapon: Weapon, player_projectiles: int = 0, player_spread: float = 0.0) -> WeaponStats:
    var result = source.duplicate()
    for prop in source.get_property_list():
        if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "script":
            var value = source.get(prop.name)
            result.set(prop.name, value.duplicate(true) if value is Array or value is Dictionary else value)
    for key in source.get_meta_list():
        result.set_meta(key, source.get_meta(key))
    if result is RangedWeaponStats:
        var ranged_source = source as RangedWeaponStats
        result.nb_projectiles = int(max(0, ranged_source.nb_projectiles - player_projectiles))
        result.projectile_spread = ranged_source.projectile_spread - player_spread
        result.set_meta(PET_BONUS.PLAYER_PROJECTILES_META, 0)
        result.set_meta(PET_BONUS.PLAYER_SPREAD_META, 0.0)
    if source.burning_data != null:
        result.burning_data = source.burning_data.duplicate()
        result.burning_data.from = weapon
    return load("res://mods-unpacked/Local-Isaac/curse_rules.gd").boost_pet_stats(result, weapon._parent.curse_factor)

static func should_attack(weapon: Weapon) -> bool:
    if weapon._is_shooting or weapon._current_cooldown > 0:
        return false
    var pet = weapon._parent
    if pet.dead or pet._end_of_wave or not pet.auto_fire or not RunData.wave_in_progress:
        return false
    if not is_instance_valid(pet.owner_player()) or pet.owner_player().dead:
        return false
    var reach = weapon.current_stats.max_range + 50.0
    if load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").eligible(weapon):
        reach = load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").attack_range(weapon)
    return weapon._current_target.size() > 0 and is_instance_valid(weapon._current_target[0]) and Utils.is_between(weapon._current_target[1], weapon.current_stats.min_range, reach)
