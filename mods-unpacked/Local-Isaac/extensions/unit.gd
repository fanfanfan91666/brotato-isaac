extends "res://entities/units/unit/unit.gd"

var isaac_custom_burn_context = false
var isaac_burn_pet_owner = -1
var isaac_burn_pet_factor = 1.0
var isaac_damage_was_crit = false

func get_move_speed() -> float:
    var native_speed = .get_move_speed()
    var slow = get_node_or_null("IsaacAquariusSlow")
    return native_speed * slow.speed_factor() if slow != null and not slow.is_queued_for_deletion() else native_speed

func take_damage(value: int, args: TakeDamageArgs) -> Array:
    if args.hitbox != null and args.hitbox.has_meta("isaac_data_hack_hit_lives"):
        var hack_life = get("isaac_poison_generation")
        if hack_life != null:
            args.hitbox.get_meta("isaac_data_hack_hit_lives")[get_instance_id()] = {"generation": int(hack_life), "position": global_position}
    # Hit listeners can recycle a body before the later projectile listeners
    # execute. Selected petrify/fear attacks share this impact-life snapshot.
    if args.hitbox != null and args.hitbox.has_meta("isaac_petrify_hit_lives"):
        var life = get("isaac_poison_generation")
        if life != null:
            args.hitbox.get_meta("isaac_petrify_hit_lives")[get_instance_id()] = int(life)
    var previous_crit = isaac_damage_was_crit
    isaac_damage_was_crit = false
    var old_context = isaac_custom_burn_context
    var old_owner = isaac_burn_pet_owner
    var old_pet_factor = isaac_burn_pet_factor
    isaac_custom_burn_context = args.has_meta("isaac_custom_burn") or args.has_meta("isaac_custom_poison")
    isaac_burn_pet_owner = int(args.get_meta("isaac_pet_tick_owner")) if isaac_custom_burn_context else -1
    isaac_burn_pet_factor = float(args.get_meta("isaac_pet_tick_factor")) if isaac_custom_burn_context and args.has_meta("isaac_pet_tick_factor") else 1.0
    var result = .take_damage(value, args)
    if isaac_damage_was_crit and result[1] > 0 and current_stats.health <= 0 and args.hitbox != null:
        load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").critical_kill(args.hitbox.from, self)
    if result[1] > 0 and current_stats.health <= 0 and args.hitbox != null:
        var weapon = args.hitbox.from
        if is_instance_valid(weapon) and weapon is Weapon and weapon.weapon_id == "weapon_local_isaac_sacrificial_dagger":
            # Parent already marked death pending, so healing-triggered effects
            # cannot re-enter this corpse and award a second heal.
            load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").dagger_kill_heal(weapon, self)
    isaac_damage_was_crit = previous_crit
    if args.hitbox != null and args.hitbox.has_meta("isaac_tough_love") and args.hitbox.get_meta("isaac_tough_love") and args.from_player_index >= 0 and args.from_player_index < RunData.get_player_count() and result[1] > 0:
        RunData.add_tracked_value(args.from_player_index, Keys.generate_hash("item_local_isaac_tough_love"), int(result[1] / 2))
    isaac_custom_burn_context = old_context
    isaac_burn_pet_owner = old_owner
    isaac_burn_pet_factor = old_pet_factor
    return result

func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: bool = true, dodgeable: bool = true, is_crit: bool = false, hitbox: Hitbox = null, is_burning: bool = false) -> Unit.GetDamageValueResult:
    isaac_damage_was_crit = is_crit
    if hitbox != null and hitbox.has_meta("isaac_data_hack_double") and hitbox.get_meta("isaac_data_hack_double"):
        dmg_value *= 2
    if hitbox != null and hitbox.has_meta("isaac_tough_love") and hitbox.get_meta("isaac_tough_love"):
        dmg_value *= 2
    var result = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)
    # Enemy adds several bonuses after Unit's calculation; its extension
    # applies the final multiplier there. Other damageable units finish here.
    if get("enemy_id") == null and (get("player_index") == null or int(get("player_index")) < 0):
        isaac_apply_final_pet_damage(result, from_player_index, hitbox, is_burning)
    return result

func isaac_apply_final_pet_damage(result, from_player_index: int, hitbox: Hitbox, is_burning: bool) -> void:
    var pet_rules = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd")
    var owner = -1
    if isaac_custom_burn_context:
        owner = isaac_burn_pet_owner
    elif hitbox != null:
        owner = pet_rules.hitbox_owner(hitbox, from_player_index)
    elif is_burning and _burning != null:
        owner = int(_burning.get_meta(pet_rules.OWNER_META)) if _burning.has_meta(pet_rules.OWNER_META) else pet_rules.source_owner(_burning.from)
    var source = hitbox.from if hitbox != null else (_burning.from if is_burning and _burning != null else null)
    var factor = isaac_burn_pet_factor if isaac_custom_burn_context else pet_rules.source_damage_factor(source)
    if pet_rules.enabled(owner):
        factor *= pet_rules.multiplier(owner)
    if result.value > 0 and factor != 1.0:
        result.value = int(round(result.value * factor))

func apply_burning(burning_data: BurningData) -> void:
    var replaces = _burning == null or _burning.damage <= burning_data.damage
    .apply_burning(burning_data)
    if dead or _burning == null or not replaces:
        return
    var rules = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd")
    var owner = int(burning_data.get_meta(rules.OWNER_META)) if burning_data.has_meta(rules.OWNER_META) else rules.source_owner(burning_data.from)
    _burning.set_meta(rules.OWNER_META, owner)
    if owner >= 0:
        _burning_player_index = owner

func stop_burning() -> void:
    .stop_burning()
    if not dead and not sleeping:
        for status in ["IsaacIpecacBurn", "IsaacBabyBurn", "IsaacDataHackBurn"]:
            var own_burn = get_node_or_null(status)
            if own_burn != null and not own_burn.is_queued_for_deletion() and not own_burn.finished:
                set_burning(true)
                return
