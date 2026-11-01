extends Reference

const ID = "weapon_local_isaac_data_hack"
const META_DOUBLE = "isaac_data_hack_double"
const META_LIVES = "isaac_data_hack_hit_lives"
const META_THROW = "isaac_data_hack_throw"
const CONTROLLER = "IsaacDataHack033"
const BURN = "IsaacDataHackBurn"
const POISON = "IsaacDataHackPoison"
const LIGHTNING = "res://projectiles/bullet_lightning/lightning_projectile.tscn"
const THROWN = "res://mods-unpacked/Local-Isaac/world/data_hack_projectile_033.tscn"
const BLAST = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const EXECUTION_EFFECT = preload("res://weapons/melee/vorpal_sword/4/vorpal_sword_4_effect_0.tres")
const RANDOM_STATS = ["stat_max_hp", "stat_armor", "stat_dodge", "stat_hp_regeneration", "stat_lifesteal", "stat_percent_damage", "stat_attack_speed", "stat_range", "stat_speed", "stat_luck", "stat_harvesting"]
# Non-lethal effects share the remaining 95%; extending this list preserves
# the explicitly fixed five-percent execution probability.
const ORDINARY_OUTCOMES = [0, 1, 2, 3, 4, 5, 6, 8, 9]
const EXECUTION = 7

static func roll_from(value: float) -> int:
    var sample = clamp(value, 0.0, 0.999999999)
    if sample < 0.05:
        return EXECUTION
    return ORDINARY_OUTCOMES[min(ORDINARY_OUTCOMES.size() - 1, int((sample - 0.05) / 0.95 * ORDINARY_OUTCOMES.size()))]

static func curse_multiplier(weapon: Node) -> float:
    if not weapon.is_cursed:
        return 1.0
    for effect in weapon.effects:
        if effect.key == "effect_local_isaac_data_hack":
            return max(1.0, 1.0 + float(effect.curse_factor))
    return 1.0

static func valid_game(data: Dictionary) -> Node:
    var game = data.game.get_ref() if data.has("game") else null
    return game if is_instance_valid(game) and game == Utils.get_scene_node() and game is Main and not game._cleaning_up and RunData.wave_in_progress else null

static func controller(weapon: Node) -> Node:
    var result = weapon.get_node_or_null(CONTROLLER)
    if result == null:
        result = load("res://mods-unpacked/Local-Isaac/world/data_hack_attack_033.gd").new()
        result.name = CONTROLLER
        weapon.add_child(result)
    return result

static func begin_attack(weapon: Node, forced_outcome: int = -1) -> Dictionary:
    var box = weapon._hitbox
    clear_attack_meta(box)
    if weapon.weapon_id != ID:
        return {}
    var game = Utils.get_scene_node()
    var p = weapon.player_index
    if not game is Main or game._cleaning_up or not RunData.wave_in_progress or p < 0 or p >= RunData.get_player_count():
        return {}
    var outcome = forced_outcome if forced_outcome >= 0 and forced_outcome <= 9 else roll_from(Utils._rng.randf())
    var data = {"outcome": outcome, "consumed": false, "owner": p, "source": weakref(weapon), "game": weakref(game), "factor": curse_multiplier(weapon), "crit_chance": weapon.current_stats.crit_chance, "crit_damage": weapon.current_stats.crit_damage}
    box.set_meta(META_DOUBLE, outcome == 8)
    if outcome in [0, 1, 2, 4, 5, 7]:
        box.set_meta(META_LIVES, {})
        controller(weapon)
    if outcome in [0, 1, 2]:
        var raw = raw_stats(outcome, data.factor)
        data.damage = WeaponService.get_explosion_damage(raw, p)
        data.scaling = raw.scaling_stats
        if outcome == 1:
            data.dot_damage = scaled_damage(5, [[Keys.stat_max_hp_hash, 0.1]], p, data.factor)
            data.dot_ticks = 3
        elif outcome == 2:
            data.dot_damage = scaled_damage(3, [[Keys.stat_armor_hash, 1.0]], p, data.factor)
            data.dot_ticks = 5
    elif outcome == 3:
        data.materials = material_amount(p, data.factor)
        RunData.add_gold(data.materials, p)
        data.consumed = true
    elif outcome == 5 or outcome == 6:
        data.projectile_stats = projectile_stats(weapon, outcome)
        if outcome == 6:
            data.projectile = fire_projectile(weapon.muzzle.global_position, weapon.global_rotation, data)
            data.consumed = true
    elif outcome == 9:
        data.points = grant_random(p, int(ceil(3 * data.factor)))
        data.consumed = true
    return data

static func double_damage(hitbox: Hitbox) -> bool:
    return hitbox != null and hitbox.has_meta(META_DOUBLE) and bool(hitbox.get_meta(META_DOUBLE))

static func clear_attack_meta(hitbox: Hitbox) -> void:
    if hitbox == null:
        return
    if hitbox.has_meta(META_DOUBLE):
        hitbox.remove_meta(META_DOUBLE)
    if hitbox.has_meta(META_LIVES):
        hitbox.remove_meta(META_LIVES)

static func raw_stats(outcome: int, factor: float = 1.0) -> WeaponStats:
    var result = WeaponStats.new()
    if outcome == 0:
        result.damage = int(ceil(100 * factor))
        result.scaling_stats = [[Keys.stat_melee_damage_hash, 1.0 * factor], [Keys.stat_ranged_damage_hash, 0.5 * factor]]
    elif outcome == 1:
        result.damage = int(ceil(50 * factor))
        result.scaling_stats = [[Keys.stat_engineering_hash, 1.0 * factor]]
    elif outcome == 2:
        result.damage = int(ceil(80 * factor))
        result.scaling_stats = [[Keys.stat_ranged_damage_hash, 0.5 * factor]]
    return result

static func scaled_damage(base: int, scaling: Array, p: int, factor: float = 1.0) -> int:
    var scaled = scaling.duplicate(true)
    for entry in scaled:
        entry[1] *= factor
    scaled = WeaponService._apply_weapon_scaling_stat_effects(scaled, p)
    return WeaponService.apply_damage_bonus(WeaponService.apply_scaling_stats_to_damage(int(ceil(base * factor)), scaled, p), p)

static func material_amount(p: int, factor: float = 1.0) -> int:
    return int(max(0, ceil((20.0 + Utils.get_stat(Keys.stat_max_hp_hash, p) * 0.1) * factor)))

static func grant_random(p: int, points: int = 3) -> Array:
    var result = []
    result.resize(RANDOM_STATS.size())
    for i in result.size():
        result[i] = 0
    for _point in max(0, points):
        var index = Utils.randi_range(0, RANDOM_STATS.size() - 1)
        result[index] += 1
    for i in result.size():
        if result[i] > 0:
            RunData.add_stat(Keys.generate_hash(RANDOM_STATS[i]), result[i], p)
    return result

static func projectile_stats(weapon: Node, outcome: int) -> RangedWeaponStats:
    var raw = RangedWeaponStats.new()
    var factor = curse_multiplier(weapon)
    raw.damage = int(ceil((20 if outcome == 5 else 100) * factor))
    raw.scaling_stats = [[Keys.stat_speed_hash, 2.0 * factor]] if outcome == 5 else [[Keys.stat_elemental_damage_hash, 1.0 * factor]]
    # Using the weapon's raw crit fields allows native initialization to add
    # player crit once, and native Unit.take_damage performs the actual roll.
    raw.crit_chance = weapon.stats.crit_chance
    raw.crit_damage = weapon.stats.crit_damage
    raw.max_range = 9999 if outcome == 5 else 700
    raw.projectile_speed = 3000 if outcome == 5 else 950
    raw.bounce = 5 if outcome == 5 else 0
    raw.bounce_dmg_reduction = 0.0
    raw.piercing = 0
    raw.piercing_dmg_reduction = 0.0
    raw.can_bounce = outcome == 5
    raw.accuracy = 1.0
    raw.effect_scale = 0.1
    raw.knockback = 0
    raw.projectile_scene = load(LIGHTNING if outcome == 5 else THROWN)
    var result = WeaponService.init_ranged_stats(raw, weapon.player_index, true)
    # These effects specify their own bounce/penetration budget; global
    # projectile-count modifiers do not produce extra copies of an outcome.
    result.nb_projectiles = 1
    result.bounce = 5 if outcome == 5 else 0
    result.bounce_dmg_reduction = 0.0
    result.piercing = 0
    result.piercing_dmg_reduction = 0.0
    if outcome == 6:
        var visual = weapon.get_node_or_null("Sprite/ApprovedArt")
        var art = visual.art if visual != null and is_instance_valid(visual.art) else weapon.sprite
        result.set_meta(META_THROW, {"texture": art.texture, "scale": art.scale.abs(), "rotation": art.rotation})
    return result

static func on_hit(weapon: Node, target: Node, damage: int, data: Dictionary, hitbox: Hitbox) -> bool:
    if data.empty() or data.get("consumed", true) or damage <= 0 or not is_instance_valid(target) or not target is Enemy or hitbox == null or hitbox.is_healing:
        return false
    var outcome = int(data.outcome)
    if not outcome in [0, 1, 2, 4, 5, 7] or valid_game(data) == null:
        return false
    var snapshot = {"generation": target.isaac_poison_generation, "position": target.global_position}
    if hitbox.has_meta(META_LIVES):
        snapshot = hitbox.get_meta(META_LIVES).get(target.get_instance_id(), snapshot)
    # A protected boss/elite still consumes this swing's selected effect.
    data.consumed = true
    controller(weapon).call_deferred("apply_first_hit", weakref(target), snapshot.generation, snapshot.position, data.duplicate())
    return true

static func apply_first_hit(target_ref: WeakRef, generation: int, position: Vector2, data: Dictionary) -> Node:
    if valid_game(data) == null:
        return null
    var source = data.source.get_ref()
    if not is_instance_valid(source):
        return null
    var target = target_ref.get_ref()
    var outcome = int(data.outcome)
    if outcome in [0, 1, 2]:
        return explode_at(position, data)
    if outcome == 5:
        var direction = source.global_rotation
        # Lightning Shiv chooses a nearby enemy from the impacted enemy's
        # spawner, then delegates all subsequent bounces to PlayerProjectile.
        if is_instance_valid(target):
            var spawner = target._entity_spawner_ref
            var next = spawner.get_rand_enemy(target) if is_instance_valid(spawner) else null
            if is_instance_valid(next):
                direction = position.direction_to(next.global_position).angle()
        var projectile = fire_projectile(position, direction, data)
        if projectile != null and valid_target(target, generation):
            projectile.set_ignored_objects([target])
        return projectile
    if not valid_target(target, generation) or target is Boss:
        return null
    if outcome == 4 and target.can_be_charmed and not target.is_loot and target.get_charmed_by_player_index() < 0:
        var behavior = target.effect_behaviors.get_node_or_null("IsaacEyeshadowCharm")
        if behavior == null:
            behavior = load("res://mods-unpacked/Local-Isaac/world/eyeshadow_charm.tscn").instance()
            behavior.init(target)
            target.effect_behaviors.add_child(behavior)
        behavior.set_meta("isaac_data_hack_charm", true)
        behavior.charm(int(data.owner))
        behavior._absorb_next_damage = false
        behavior._charm_timer.start(8.0 * data.factor)
        return behavior
    elif outcome == 7 and target.get_charmed_by_player_index() < 0:
        # A private hitbox preserves native death, loot, kill signals and the
        # weapon's own damage counter without fabricating a critical hit.
        var box = Hitbox.new()
        box.from = source
        var execute = EXECUTION_EFFECT.duplicate()
        execute.value = 100
        box.effects = [execute]
        box.crit_chance = 0.0
        var args = TakeDamageArgs.new(int(data.owner), box)
        args.armor_applied = false
        args.dodgeable = false
        args.bypass_invincibility = true
        box.connect("killed_something", source, "on_killed_something", [box])
        var taken = target.take_damage(1, args)
        track_damage(data, target, int(taken[1]))
        box.queue_free()
    return null

static func valid_target(target: Node, generation: int) -> bool:
    return is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die and not target.sleeping and target.isaac_poison_generation == generation

static func track_damage(data: Dictionary, target: Node, damage: int) -> void:
    var source = data.source.get_ref()
    if damage <= 0 or not is_instance_valid(source):
        return
    if source.weapon_pos >= 0:
        source.on_weapon_hit_something(target, damage, null)
    else:
        RunData.add_tracked_value(int(data.owner), Keys.generate_hash("item_local_isaac_incubus"), damage)

static func fire_projectile(position: Vector2, direction: float, data: Dictionary) -> Node:
    if valid_game(data) == null:
        return null
    var source = data.source.get_ref()
    if not is_instance_valid(source):
        return null
    var args = WeaponServiceSpawnProjectileArgs.new()
    args.from_player_index = int(data.owner)
    args.knockback_direction = Vector2.RIGHT.rotated(direction)
    if source.weapon_pos < 0:
        args.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_incubus")
    var projectile = WeaponService.spawn_projectile(position, data.projectile_stats, direction, source, args)
    if source.weapon_pos >= 0:
        projectile.connect("hit_something", source, "on_weapon_hit_something", [projectile._hitbox])
    projectile._hitbox.connect("killed_something", source, "on_killed_something", [projectile._hitbox])
    projectile.connect("critically_hit_something", source, "_on_weapon_critically_hit_something")
    return projectile

static func explode_at(position: Vector2, data: Dictionary) -> Node:
    if valid_game(data) == null:
        return null
    var source = data.source.get_ref()
    if not is_instance_valid(source):
        return null
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = position
    args.damage = int(data.damage)
    args.scaling_stats = data.scaling
    args.accuracy = 1.0
    args.crit_chance = data.crit_chance
    args.crit_damage = data.crit_damage
    args.from_player_index = int(data.owner)
    args.from = source
    if source.weapon_pos < 0:
        args.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_incubus")
    var explosion = WeaponService.explode(BLAST, args)
    explosion._hitbox.set_meta(META_DOUBLE, false)
    if explosion._hitbox.has_meta(META_LIVES):
        explosion._hitbox.remove_meta(META_LIVES)
    if source.weapon_pos >= 0:
        explosion.connect("hit_something", source, "on_weapon_hit_something", [explosion._hitbox])
    explosion.connect("killed_something", source, "on_killed_something", [explosion._hitbox])
    if int(data.outcome) in [1, 2]:
        explosion._hitbox.set_meta(META_LIVES, {})
        var color = Color(1.0, 0.45, 0.12) if int(data.outcome) == 1 else Color(0.4, 1.0, 0.25)
        color.a = ProgressData.settings.explosion_opacity
        explosion._sprite.modulate = color
        explosion.connect("hit_something", controller(source), "on_explosion_hit", [explosion._hitbox, data.duplicate()])
    return explosion

static func apply_dot(target: Node, generation: int, data: Dictionary) -> Node:
    if valid_game(data) == null or not valid_target(target, generation) or target.get_charmed_by_player_index() >= 0:
        return null
    if int(data.outcome) == 1 and RunData.get_player_effect(Keys.can_burn_enemies_hash, int(data.owner)) <= 0:
        return null
    var status_name = BURN if int(data.outcome) == 1 else POISON
    var status = target.get_node_or_null(status_name)
    if status == null or status.is_queued_for_deletion() or status.finished:
        status = load("res://mods-unpacked/Local-Isaac/world/data_hack_dot_033.gd").new()
        status.name = status_name
        status.refresh(data)
        target.add_child(status)
    else:
        status.refresh(data)
    return status

static func clear_status(target: Node) -> void:
    for status_name in [BURN, POISON]:
        var status = target.get_node_or_null(status_name)
        if status != null and not status.is_queued_for_deletion():
            status.finish()

static func clear_charm(target: Node) -> void:
    # Native Unit.die releases its effect behaviors. Direct free_entity and
    # immediate pool reuse can bypass death, so remove only our dynamic charm
    # synchronously before Enemy.respawn reinitializes the native container.
    var behavior = target.effect_behaviors.get_node_or_null("IsaacEyeshadowCharm") if target.effect_behaviors != null else null
    if behavior == null or not behavior.has_meta("isaac_data_hack_charm"):
        return
    behavior.uncharm()
    target.effect_behaviors.remove_child(behavior)
    behavior.queue_free()
