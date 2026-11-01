extends "res://projectiles/player_projectile.gd"

func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float, p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array, hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    .shoot_ex(p_from, pos, p_velocity, p_rotation, p_weapon_stats, damage_tracking_key, effects, hitbox_args, knockback_direction)
    _hitbox.set_meta("isaac_data_hack_double", false)
    if _hitbox.has_meta("isaac_data_hack_hit_lives"):
        _hitbox.remove_meta("isaac_data_hack_hit_lives")
    var visual = p_weapon_stats.get_meta("isaac_data_hack_throw")
    _sprite.texture = visual.texture
    _sprite.scale = visual.scale
    _sprite.rotation = visual.rotation
    _sprite.modulate = Color(1, 1, 1, ProgressData.settings.projectile_opacity)
    var shape = CircleShape2D.new()
    shape.radius = 24
    $Hitbox/Collision.shape = shape

func _physics_process(delta: float) -> void:
    # Godot 3 automatically dispatches inherited process notifications; calling
    # the parent explicitly would decrement the projectile lifetime twice.
    _sprite.rotation += delta * TAU * 2.0

func _on_Hitbox_hit_something(target: Node, damage: int) -> void:
    # Infinite penetration uses the native per-projectile ignored-object set;
    # no arbitrary numeric budget can be exhausted by a large enemy wave.
    emit_signal("hit_something", target, damage)
    RunData.manage_life_steal(_weapon_stats, _get_player_index())
    _hitbox.ignored_objects.append(target)

func _return_to_pool() -> void:
    _sprite.rotation = 0.0
    _hitbox.ignored_objects.clear()
    _hitbox.set_meta("isaac_data_hack_double", false)
    if _hitbox.has_meta("isaac_data_hack_hit_lives"):
        _hitbox.remove_meta("isaac_data_hack_hit_lives")
    ._return_to_pool()
