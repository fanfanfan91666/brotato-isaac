extends "res://projectiles/player_projectile.gd"

const RULES = preload("res://mods-unpacked/Local-Isaac/baby_rules.gd")
var baby_shot = {}
var detonated = false

func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float, p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array, hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    baby_shot = p_weapon_stats.get_meta("isaac_baby_shot").duplicate(true)
    baby_shot.tracking = damage_tracking_key
    detonated = false
    .shoot_ex(p_from, pos, p_velocity, p_rotation, p_weapon_stats, damage_tracking_key, effects, hitbox_args, knockback_direction)
    _hitbox.set_meta("isaac_tough_love", false)
    _hitbox.deals_damage = not (baby_shot.kind == 3 and baby_shot.mode == 1)
    if baby_shot.kind == 3 and baby_shot.mode in [0, 2]:
        # These tears use a one-second custom burn, separate from native half-second ticks.
        _hitbox.burning_data = BurningData.new()
    var tint = Color.white
    if baby_shot.kind == 3:
        tint = [Color(1, 0.25, 0.25), Color(0.15, 0.15, 0.2), Color(0.3, 1, 0.2), Color.white, Color.white][baby_shot.mode]
    elif baby_shot.kind == 5:
        tint = Color(0.1, 0.1, 0.13)
    tint.a = ProgressData.settings.projectile_opacity * (0.55 if baby_shot.infinite else 1.0)
    _sprite.modulate = tint

func _on_Hitbox_hit_something(target: Node, damage: int) -> void:
    if baby_shot.kind == 3 and baby_shot.mode in [0, 2]:
        RULES.apply_burn(target, baby_shot)
    if baby_shot.infinite:
        _hitbox.ignored_objects.append(target)
        emit_signal("hit_something", target, damage)
        RunData.manage_life_steal(_weapon_stats, _get_player_index())
    else:
        ._on_Hitbox_hit_something(target, damage)

func stop() -> void:
    if not detonated and baby_shot.get("kind", -1) == 3 and baby_shot.mode == 1:
        detonated = true
        var game = Utils.get_scene_node()
        if game is Main and not game._cleaning_up and RunData.wave_in_progress:
            game.call_deferred("isaac_baby_explode", global_position, baby_shot.duplicate(true))
    .stop()

func _return_to_pool() -> void:
    _hitbox.deals_damage = true
    _hitbox.set_meta("isaac_tough_love", false)
    ._return_to_pool()
