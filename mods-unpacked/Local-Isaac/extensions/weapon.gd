extends "res://weapons/weapon.gd"

var isaac_rib_attack_id = -1
var isaac_rib_attack_enemy_kills = 0

func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    if weapon_id == "weapon_local_isaac_pointed_rib":
        # Saved WeaponData can retain the old false flag. The native MeleeWeapon
        # reads stats for alternation; no saved numeric combat stats are changed.
        stats.alternate_attack_type = true
        current_stats.alternate_attack_type = true
    if load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").eligible(self):
        load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").sync(self, true)

func should_shoot() -> bool:
    if load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").eligible(self):
        return load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd").should_attack(self)
    return .should_shoot()

func shoot() -> void:
    .shoot()
    load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").on_attack(self)
    var game = Utils.get_scene_node()
    if game is Main and game.get("isaac_bomb_system") != null:
        game.isaac_bomb_system.on_weapon_attack(self)

func on_weapon_hit_something(target: Node, damage_dealt: int, hitbox: Hitbox) -> void:
    .on_weapon_hit_something(target, damage_dealt, hitbox)
    load("res://mods-unpacked/Local-Isaac/poison_rules.gd").weapon_hit(target, self, hitbox)

func on_killed_something(target: Node, hitbox: Hitbox) -> void:
    .on_killed_something(target, hitbox)
    if weapon_id == "weapon_local_isaac_pointed_rib":
        load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").rib_attack_kill(self, target, hitbox)
    elif weapon_id == "weapon_local_isaac_wooden_nickel":
        load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").nickel_kill(self, target)

func _on_weapon_critically_hit_something(_thing_hit, _damage_dealt) -> void:
    var visual = get_node_or_null("Sprite/ApprovedArt")
    if visual == null:
        ._on_weapon_critically_hit_something(_thing_hit, _damage_dealt)
        return
    # Native self_modulate flashes make the hidden carrier opaque forever.
    tween_animation.interpolate_property(visual, "modulate", Color(1.6, 1.6, 1), Color.white, 0.16, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
    tween_animation.start()
