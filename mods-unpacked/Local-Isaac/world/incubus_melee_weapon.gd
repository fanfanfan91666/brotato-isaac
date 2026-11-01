extends "res://weapons/melee/melee_weapon.gd"

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

func on_weapon_hit_something(_target: Node, _damage: int, _hitbox_ref: Hitbox) -> void:
    pass
