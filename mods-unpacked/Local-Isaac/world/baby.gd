extends "res://entities/units/pet/pet.gd"

const RULES = preload("res://mods-unpacked/Local-Isaac/baby_rules.gd")
export(int, "Bobby", "Maggy", "Ghost", "Rainbow", "Seraphim", "Little Steven", "Demon Baby") var baby_kind = 0
export(String) var custom_tracking_id = ""
export(bool) var is_stationary = false
export(bool) var winged = false
export(float) var wing_split_ratio = 0.35
var pet_motion: Node
var follow_motion = preload("res://mods-unpacked/Local-Isaac/world/smooth_pet_follow.gd").new()
var follow_speed = 0.0
var modes = []
var targets = []
var cooldown_left = 0.0
var auto_fire = true
var shots_fired = 0
var shot_times = []
var last_projectiles = []
var last_mode = 3
var curse_factor = 0.0

func _ready() -> void:
    $EnemyRange.connect("body_entered", self, "on_enemy_entered")
    $EnemyRange.connect("body_exited", self, "on_enemy_exited")
    _hurtbox.set_deferred("monitoring", false)
    _animation_player.play("idle")
    _movement_behavior._target_player = true
    pet_motion = load("res://mods-unpacked/Local-Isaac/world/pet_motion.gd").attach(self, $Animation/Sprite, winged, wing_split_ratio)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    curse_factor = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").effect_factor(effect, player_index, RULES.IDS[baby_kind])
    can_drop_loot = false
    reload_data()
    _can_move = not is_stationary
    if not is_stationary and is_instance_valid(current_target):
        var follow_pos = current_target.global_position + Vector2(rand_range(150, 180), 0).rotated(rand_range(-PI, PI))
        global_position = Vector2(clamp(follow_pos.x, _min_pos.x, _max_pos.x), clamp(follow_pos.y, _min_pos.y, _max_pos.y))
        follow_motion.reset(current_target.global_position)

func should_data_be_reload() -> bool:
    return true

func reload_data() -> void:
    modes = build_attack_stats()
    update_range()

func build_attack_stats() -> Array:
    var result = []
    if baby_kind == 3:
        for mode in range(5):
            result.append(RULES.init_stats(baby_kind, player_index, mode, curse_factor))
    else:
        result.append(RULES.init_stats(baby_kind, player_index, 3, curse_factor))
    return result

func get_movement() -> Vector2:
    if is_stationary:
        return Vector2.ZERO
    if _move_locked:
        return _current_movement
    var separation = pet_motion.separation_vector() if pet_motion != null else Vector2.ZERO
    var movement = follow_motion.update(self, current_target, .get_move_speed(), separation, get_physics_process_delta_time())
    follow_speed = movement.length()
    return movement

func get_move_speed() -> float:
    return follow_speed if not is_stationary else 0.0

func get_stats() -> Array:
    return modes

func set_current_stats(values: Array) -> void:
    modes = values
    update_range()

func update_range() -> void:
    if not modes.empty():
        $EnemyRange/CollisionShape2D.shape.radius = modes[0].max_range

func take_damage(_value: int, _args: TakeDamageArgs) -> Array:
    return [0, 0, false]

func on_enemy_entered(body: Node) -> void:
    if body is Enemy and not targets.has(body):
        targets.append(body)

func on_enemy_exited(body: Node) -> void:
    targets.erase(body)

func _physics_process(delta: float) -> void:
    if dead or _end_of_wave or not RunData.wave_in_progress or modes.empty():
        return
    cooldown_left = max(0.0, cooldown_left - 60.0 * delta)
    if not auto_fire or cooldown_left > 0:
        return
    var nearest: Node2D = null
    var closest = float(modes[0].max_range * modes[0].max_range)
    for target in targets:
        if not is_instance_valid(target) or target.dead or target.sleeping or target.get_charmed_by_player_index() >= 0:
            continue
        var distance = global_position.distance_squared_to(target.global_position)
        if distance < closest:
            closest = distance
            nearest = target
    if nearest != null:
        var origin = global_position + Vector2(0, -24)
        var hurtbox = nearest.get_node_or_null("Hurtbox")
        var aim = hurtbox.global_position if hurtbox != null else nearest.global_position
        fire_at((aim - origin).angle())

func fire_at(direction: float, selected_mode: int = -1) -> Array:
    last_mode = selected_mode if selected_mode >= 0 else (RULES.choose_mode() if baby_kind == 3 else 3)
    var shot = modes[last_mode if baby_kind == 3 else 0].duplicate()
    var data = RULES.burn_data(player_index, curse_factor)
    data.kind = baby_kind
    data.mode = last_mode
    if baby_kind == 3 and last_mode == 2:
        data.poison = true
        data.status = "IsaacBabyPoison"
    data.infinite = baby_kind == 2 or (baby_kind == 3 and last_mode == 4)
    data.damage = shot.damage
    data.crit_chance = shot.crit_chance
    data.crit_damage = shot.crit_damage
    shot.set_meta("isaac_baby_shot", data)
    var args = WeaponServiceSpawnProjectileArgs.new()
    args.from_player_index = player_index
    args.damage_tracking_key_hash = Keys.generate_hash(custom_tracking_id if custom_tracking_id != "" else "item_local_isaac_" + RULES.IDS[baby_kind])
    last_projectiles = []
    for _i in range(shot.nb_projectiles):
        var angle = direction + rand_range(-shot.projectile_spread, shot.projectile_spread)
        args.knockback_direction = Vector2.RIGHT.rotated(angle)
        last_projectiles.append(WeaponService.spawn_projectile(global_position + Vector2(0, -24), shot, angle, self, args))
    cooldown_left = shot.cooldown
    shots_fired += 1
    if pet_motion != null:
        pet_motion.pulse(direction)
    shot_times.append(Engine.get_physics_frames())
    return last_projectiles

func end_of_wave_callback() -> void:
    .end_of_wave_callback()
    _can_move = false
