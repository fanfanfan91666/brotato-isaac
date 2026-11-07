extends "res://projectiles/player_projectile.gd"

const RULES = preload("res://mods-unpacked/Local-Isaac/attack_rules.gd")
const NAIL_TRACKING = "item_local_isaac_eight_inch_nails"
const TOUGH_TRACKING = "item_local_isaac_tough_love"
const TEAR = preload("res://mods-unpacked/Local-Isaac/content/weapons/tear/tear.png")
const NAILS = preload("res://mods-unpacked/Local-Isaac/content/items/eight_inch_nails/icon.png")
const KNUCKLES = preload("res://mods-unpacked/Local-Isaac/content/items/tough_love/icon.png")
var isaac_proc = {}
var isaac_detonated = false
var isaac_stop_position = Vector2.ZERO

func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float, p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array, hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    isaac_proc = p_weapon_stats.get_meta(RULES.META).duplicate(true)
    isaac_detonated = false
    isaac_stop_position = Vector2.ZERO
    var actual_effects = []
    for effect in effects:
        if not isaac_proc.ipecac or not effect is ExplodingEffect:
            actual_effects.append(effect)
    .shoot_ex(p_from, pos, p_velocity, p_rotation, p_weapon_stats, damage_tracking_key, actual_effects, hitbox_args, knockback_direction)
    # Ranged damage was doubled on this shot's private stats; melee uses a marker.
    _hitbox.set_meta(RULES.TOUGH, false)
    _hitbox.deals_damage = not isaac_proc.ipecac
    if isaac_proc.nail:
        _hitbox.damage_tracking_key_hash = Keys.generate_hash(NAIL_TRACKING)
    _sprite.rotation = 0
    _sprite.modulate = Color(1, 1, 1, ProgressData.settings.projectile_opacity)
    var shape = CircleShape2D.new()
    shape.radius = 20
    $Hitbox/Collision.shape = shape
    if isaac_proc.ipecac:
        _sprite.texture = TEAR
        _sprite.scale = Vector2(0.085, 0.085)
        _sprite.modulate = Color(0.35, 1.0, 0.2, ProgressData.settings.projectile_opacity)
        shape.radius = 28
    elif isaac_proc.nail:
        var atlas = AtlasTexture.new()
        atlas.atlas = NAILS
        atlas.region = Rect2(15, 1, 16, 30)
        _sprite.texture = atlas
        _sprite.scale = Vector2(2.5, 2.5)
        _sprite.rotation = PI / 2
        var rectangle = RectangleShape2D.new()
        rectangle.extents = Vector2(35, 8)
        $Hitbox/Collision.shape = rectangle
    else:
        _sprite.texture = KNUCKLES
        _sprite.scale = Vector2(3, 3)
    $ToughOverlay.visible = isaac_proc.tough and (isaac_proc.nail or isaac_proc.ipecac)

func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    # Tough Love contributes the extra half of a doubled hit. The hitbox/weapon
    # still owns the base damage, so only the bonus is attributed here.
    if isaac_proc.get("tough", false) and damage_dealt > 0:
        RunData.add_tracked_value(_get_player_index(), Keys.generate_hash(TOUGH_TRACKING), int(damage_dealt / 2))
    if isaac_proc.nail:
        _hitbox.ignored_objects.append(thing_hit)
        emit_signal("hit_something", thing_hit, damage_dealt)
        if not isaac_proc.ipecac:
            RunData.manage_life_steal(_weapon_stats, _get_player_index())
    else:
        ._on_Hitbox_hit_something(thing_hit, damage_dealt)

func stop(from_screen_border: bool = false) -> void:
    if not isaac_detonated and isaac_proc.get("ipecac", false):
        isaac_detonated = true
        isaac_stop_position = global_position
        RULES.explode_at(global_position, isaac_proc)
    .stop(from_screen_border)

func _return_to_pool() -> void:
    _hitbox.set_meta(RULES.TOUGH, false)
    _hitbox.deals_damage = true
    $ToughOverlay.hide()
    ._return_to_pool()
