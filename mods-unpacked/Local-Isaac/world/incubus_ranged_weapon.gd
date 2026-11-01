extends "res://weapons/ranged/ranged_weapon.gd"

const COPY = preload("res://mods-unpacked/Local-Isaac/world/incubus_weapon_rules.gd")
var source_weapon: Weapon

func init_stats(at_wave_begin: bool = true) -> void:
    COPY.sync(self, at_wave_begin)

func is_manual_aim() -> bool:
    return false

func should_shoot() -> bool:
    return COPY.should_attack(self)

func shoot() -> void:
    _parent.on_copy_attack(rotation)
    .shoot()

func on_projectile_shot(projectile: Node2D) -> void:
    if is_instance_valid(projectile):
        _parent.last_projectiles.append(projectile)
        projectile._hitbox.damage_tracking_key_hash = Keys.generate_hash(COPY.TRACKING)
    .on_projectile_shot(projectile)

func on_weapon_hit_something(_target: Node, _damage: int, _hitbox_ref: Hitbox) -> void:
    # The native hitbox tracks damage against the Incubus item. A pet copy has
    # no weapon slot in the player's inventory and must not write slot -1.
    pass
