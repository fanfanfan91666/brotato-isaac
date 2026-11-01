extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"

const ISAAC_PROCS = preload("res://mods-unpacked/Local-Isaac/attack_rules.gd")
var isaac_utility_state = {}

func shoot(distance: float) -> void:
    var original = _parent.current_stats
    var state = ISAAC_PROCS.roll(_parent)
    isaac_utility_state = load("res://mods-unpacked/Local-Isaac/new_items_019.gd").roll(_parent.player_index) if _parent._parent is Player else {}
    load("res://mods-unpacked/Local-Isaac/world/fear_041.gd").roll(_parent, isaac_utility_state)
    if _parent.weapon_id == "weapon_local_isaac_boomerang":
        var chance = load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").value(_parent, "boomerang_petrify", [5, 10, 15, 20][clamp(_parent.tier, 0, 3)])
        isaac_utility_state["petrify"] = Utils.get_chance_success(clamp(chance / 100.0, 0.0, 1.0))
        isaac_utility_state["petrify_duration"] = 2.0
    if ISAAC_PROCS.any_proc(state):
        _parent.current_stats = ISAAC_PROCS.projectile_stats(_parent, original, state)
    .shoot(distance)
    _parent.current_stats = original

func shoot_projectile(rotation: float = _parent.rotation, knockback: Vector2 = Vector2.ZERO) -> Node:
    var projectile = .shoot_projectile(rotation, knockback)
    load("res://mods-unpacked/Local-Isaac/world/attack_utility.gd").attach(projectile, projectile._hitbox, _parent.player_index, isaac_utility_state)
    return projectile
