extends Node

var last_result: Node
var last_outcome = -1
var last_dot: Node

func apply_first_hit(target_ref: WeakRef, generation: int, position: Vector2, data: Dictionary) -> void:
    last_outcome = int(data.outcome)
    last_result = load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").apply_first_hit(target_ref, generation, position, data)

func on_explosion_hit(target: Node, damage: int, hitbox: Hitbox, data: Dictionary) -> void:
    if damage <= 0 or not is_instance_valid(target) or not target is Enemy:
        return
    var snapshot = {"generation": target.isaac_poison_generation}
    if hitbox.has_meta("isaac_data_hack_hit_lives"):
        snapshot = hitbox.get_meta("isaac_data_hack_hit_lives").get(target.get_instance_id(), snapshot)
    call_deferred("apply_dot", weakref(target), snapshot.generation, data)

func apply_dot(target_ref: WeakRef, generation: int, data: Dictionary) -> void:
    last_dot = load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").apply_dot(target_ref.get_ref(), generation, data)
