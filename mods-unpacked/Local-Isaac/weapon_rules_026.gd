extends Reference

const SWORD = "weapon_local_isaac_spirit_sword"
const DAGGER = "weapon_local_isaac_sacrificial_dagger"
const NICKEL = "weapon_local_isaac_wooden_nickel"
const PICKAXE = "weapon_local_isaac_broken_pickaxe"
const RIB = "weapon_local_isaac_pointed_rib"
const WAVE = preload("res://mods-unpacked/Local-Isaac/content/weapons/spirit_sword/wave.tscn")

static func value(weapon: Node, name: String, fallback: int) -> int:
    for effect in weapon.effects:
        if effect.key == "effect_local_isaac_" + name:
            return int(effect.value)
    return fallback

static func coin_threshold(tier: int) -> int:
    return [25, 20, 15, 10][clamp(tier, 0, 3)]

static func owned_data(weapon: Node) -> Resource:
    if not weapon._parent is Player or weapon.weapon_pos < 0:
        return null
    var owned = RunData.get_player_weapons_ref(weapon.player_index)
    if weapon.weapon_pos >= owned.size():
        return null
    var result = owned[weapon.weapon_pos]
    return result if result.weapon_id == weapon.weapon_id else null

static func beam_stats(p: int, source: Node = null) -> RangedWeaponStats:
    var raw = RangedWeaponStats.new()
    raw.damage = 10
    raw.scaling_stats = [[Keys.stat_melee_damage_hash, 1.0]]
    raw.crit_chance = source.stats.crit_chance if source != null else 0.03
    raw.crit_damage = source.stats.crit_damage if source != null else 2.0
    raw.knockback = 5
    raw.max_range = 500
    raw.projectile_speed = 1100
    raw.projectile_scene = WAVE
    raw.nb_projectiles = 1
    raw.piercing = 1
    raw.accuracy = 1.0
    return WeaponService.init_ranged_stats(raw, p, true)

static func fire_wave(weapon: Node) -> Node:
    var args = WeaponServiceSpawnProjectileArgs.new()
    args.from_player_index = weapon.player_index
    args.knockback_direction = Vector2.RIGHT.rotated(weapon.global_rotation)
    args.effects = weapon.effects
    if weapon.weapon_pos < 0:
        args.damage_tracking_key_hash = weapon.damage_tracking_key_hash
    var projectile = WeaponService.spawn_projectile(weapon.muzzle.global_position, beam_stats(weapon.player_index, weapon), weapon.global_rotation, weapon, args)
    if weapon.weapon_pos >= 0:
        projectile.connect("hit_something", weapon, "on_weapon_hit_something", [projectile._hitbox])
    projectile._hitbox.connect("killed_something", weapon, "on_killed_something", [projectile._hitbox])
    projectile.connect("critically_hit_something", weapon, "_on_weapon_critically_hit_something")
    return projectile

static func settle_coin(data: Resource, p: int) -> int:
    var threshold = coin_threshold(data.tier)
    for effect in data.effects:
        if effect.key == "effect_local_isaac_nickel_growth":
            threshold = max(1, int(effect.value))
    var count = int(data.isaac_coin_progress / threshold)
    if count > 0:
        data.isaac_coin_progress %= threshold
        RunData.add_stat(Keys.stat_percent_damage_hash, count, p)
    return count

static func gain_coin(weapon: Node) -> void:
    var p = weapon.player_index
    RunData.add_gold(1, p)
    var data = owned_data(weapon)
    if data != null:
        # Same native per-weapon counter/signal used by the Thief Dagger.
        weapon.emit_signal("tracked_value_updated", 1)
        data.isaac_coin_progress += 1
        settle_coin(data, p)
    else:
        # A copied pet weapon owns a separate, temporary actor counter.
        var progress = int(weapon.get_meta("isaac_coin_progress")) if weapon.has_meta("isaac_coin_progress") else 0
        progress += 1
        var threshold = max(1, value(weapon, "nickel_growth", coin_threshold(weapon.tier)))
        if progress >= threshold:
            RunData.add_stat(Keys.stat_percent_damage_hash, int(progress / threshold), p)
            progress %= threshold
        weapon.set_meta("isaac_coin_progress", progress)

static func on_attack(weapon: Node) -> void:
    if weapon.weapon_id == SWORD:
        var chance = value(weapon, "spirit_wave", [5, 10, 15, 20][clamp(weapon.tier, 0, 3)])
        if Utils.get_chance_success(chance / 100.0):
            fire_wave(weapon)

static func nickel_kill(weapon: Node, victim: Node) -> bool:
    if weapon.weapon_id != NICKEL or not victim is Enemy or victim.get_charmed_by_player_index() >= 0:
        return false
    var chance = value(weapon, "nickel_coin", [10, 20, 30, 40][clamp(weapon.tier, 0, 3)])
    if not Utils.get_chance_success(clamp(chance / 100.0, 0.0, 1.0)):
        return false
    gain_coin(weapon)
    return true

static func add_rib_clear(weapon: Node, utility: Dictionary) -> void:
    if weapon.weapon_id != RIB:
        return
    # One roll for the whole melee attack. Keep Lost Contact's own successful
    # roll separate so a Rib-only clear never inflates that item's tracker.
    utility["track_contact"] = utility.get("clear", false)
    var chance = value(weapon, "rib_clear", [5, 10, 15, 20][clamp(weapon.tier, 0, 3)])
    var clear = Utils.get_chance_success(clamp(chance / 100.0, 0.0, 1.0))
    utility["clear"] = utility.get("clear", false) or clear

static func pickaxe_break(weapon: Node) -> bool:
    if not is_instance_valid(weapon) or not weapon is Weapon or weapon.weapon_id != PICKAXE:
        return false
    var chance = value(weapon, "pickaxe_growth", [40, 60, 80, 100][clamp(weapon.tier, 0, 3)])
    if not Utils.get_chance_success(chance / 100.0):
        return false
    RunData.add_stat(Keys.stat_percent_damage_hash, 1, weapon.player_index)
    if owned_data(weapon) != null:
        weapon.emit_signal("tracked_value_updated", 1)
    return true

static func rib_attack_kill(weapon: Node, victim: Node, hitbox: Hitbox) -> bool:
    if weapon.weapon_id != RIB or not weapon._parent is Player or weapon.weapon_pos < 0:
        return false
    if hitbox == null or hitbox != weapon._hitbox or not victim is Enemy or victim.get_charmed_by_player_index() >= 0:
        return false
    var attack_id = hitbox.player_attack_id
    if attack_id < 0:
        return false
    # Reuse Dwarf's native attack identity and equality rule. Unit can report
    # Neutral deaths to the parent's counter as well, so keep only this one
    # attack's eligible Enemy count without changing Dwarf's own dictionary.
    if weapon.isaac_rib_attack_id != attack_id:
        weapon.isaac_rib_attack_id = attack_id
        weapon.isaac_rib_attack_enemy_kills = 0
    weapon.isaac_rib_attack_enemy_kills += 1
    var threshold = max(1, value(weapon, "rib_growth", [10, 9, 8, 6][clamp(weapon.tier, 0, 3)]))
    if weapon.isaac_rib_attack_enemy_kills != threshold:
        return false
    RunData.add_stat(Keys.stat_percent_damage_hash, 1, weapon.player_index)
    weapon.emit_signal("tracked_value_updated", 1)
    return true

static func critical_kill(weapon: Node, victim: Node) -> bool:
    if not is_instance_valid(weapon) or not weapon is Weapon or weapon.weapon_id != DAGGER or not victim is Enemy or victim.get_charmed_by_player_index() >= 0:
        return false
    var p = weapon.player_index
    if p < 0 or not RunData.get_player_effects(p).has(Keys.stat_curse_hash):
        return false
    var chance = value(weapon, "sacrifice_curse", [1, 2, 3, 5][clamp(weapon.tier, 0, 3)])
    if not Utils.get_chance_success(chance / 100.0):
        return false
    RunData.add_stat(Keys.stat_curse_hash, 1, p)
    weapon.emit_signal("tracked_value_updated", 1)
    return true

static func cursed_enemy(victim: Node) -> bool:
    if not victim is Enemy:
        return false
    for behavior in victim.effect_behaviors.get_children():
        var script = behavior.get_script()
        while script != null:
            if script.resource_path.get_basename().ends_with("/curse_enemy_effect_behavior"):
                return true
            script = script.get_base_script()
    return false

static func dagger_kill_heal(weapon: Node, victim: Node) -> bool:
    if not is_instance_valid(weapon) or weapon.weapon_id != DAGGER or not victim is Enemy or victim.get_charmed_by_player_index() >= 0 or not cursed_enemy(victim):
        return false
    var chance = value(weapon, "sacrifice_heal", [20, 30, 40, 50][clamp(weapon.tier, 0, 3)])
    if not Utils.get_chance_success(chance / 100.0):
        return false
    RunData.emit_signal("healing_effect", 1, weapon.player_index, Keys.empty_hash)
    return true
