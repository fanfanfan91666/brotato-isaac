extends Node

# A timed multiplier is read by the existing Unit extension after native speed
# calculation. Native weapon slows and charging speed are never overwritten.
var target: Node
var game: Node
var effects = {}
var disposed = false

static func apply(enemy: Node, owner_index: int, percent: float, duration: float) -> Node:
    if not is_instance_valid(enemy) or enemy.dead or enemy.sleeping or duration <= 0.0:
        return null
    var status = enemy.get_node_or_null("IsaacAquariusSlow")
    if status == null or status.is_queued_for_deletion():
        status = load("res://mods-unpacked/Local-Isaac/world/aquarius_slow.gd").new()
        status.name = "IsaacAquariusSlow"
        status.target = enemy
        status.game = Utils.get_scene_node()
        enemy.add_child(status)
    status.effects[owner_index] = [clamp(percent, 0.0, 100.0), duration]
    return status

func _ready() -> void:
    target.connect("died", self, "on_target_died")

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if disposed or (is_inside_tree() and get_tree().paused):
        return
    if not valid_target() or not RunData.wave_in_progress or game != Utils.get_scene_node():
        clear()
        return
    for owner in effects.keys():
        effects[owner][1] = max(0.0, float(effects[owner][1]) - max(0.0, delta))
        if effects[owner][1] < 0.000001:
            effects.erase(owner)
    if effects.empty():
        clear()

func valid_target() -> bool:
    return is_instance_valid(target) and not target.dead and not target.sleeping and not target.cleaning_up and is_instance_valid(game) and game.get("_cleaning_up") == false

func speed_factor() -> float:
    if disposed or not valid_target() or not RunData.wave_in_progress:
        return 1.0
    var strongest = 0.0
    for row in effects.values():
        strongest = max(strongest, float(row[0]))
    return 1.0 - strongest / 100.0

func on_target_died(_enemy, _args) -> void:
    clear()

func clear() -> void:
    if disposed:
        return
    disposed = true
    effects.clear()
    # A pooled enemy may be respawned before the deferred free runs.
    name = "ExpiredAquariusSlow"
    queue_free()

func _exit_tree() -> void:
    # Native Main removes pooled nodes from the scene tree even when an
    # unusual caller skips the normal enemy death signal.
    clear()

