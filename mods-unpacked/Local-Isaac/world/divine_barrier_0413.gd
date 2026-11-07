extends Node

# Charges belong to this player and battle, separate from native hit protection.
var player: Node = null
var interval = 20.0
var elapsed = 0.0
var charges = 0
var active_wave = -1
var finished = false

static func attach(owner_player: Node):
    var p = int(owner_player.player_index)
    if RunData.get_nb_item(Keys.generate_hash("item_local_isaac_divine_barrier"), p) <= 0:
        return null
    var result = load("res://mods-unpacked/Local-Isaac/world/divine_barrier_0413.gd").new()
    result.name = "IsaacDivineBarrier"
    result.player = owner_player
    result.interval = max(0.1, load("res://mods-unpacked/Local-Isaac/curse_rules.gd").min_value("divine_barrier", p, "interval", 20.0))
    owner_player.add_child(result)
    return result

func _ready() -> void:
    var game = Utils.get_scene_node()
    if game is Main:
        game.connect("end_of_the_wave", self, "finish")

func finish() -> void:
    finished = true
    charges = 0
    elapsed = 0.0
    active_wave = -1

func ensure_wave() -> bool:
    if finished or not is_instance_valid(player) or not RunData.wave_in_progress:
        charges = 0
        elapsed = 0.0
        active_wave = -1
        return false
    if active_wave != RunData.current_wave:
        active_wave = RunData.current_wave
        charges = 0
        elapsed = 0.0
    return not player.dead

func ready_to_block() -> bool:
    return ensure_wave() and charges > 0

func consume() -> void:
    if ready_to_block():
        charges -= 1

func _physics_process(delta: float) -> void:
    if get_tree().paused or not ensure_wave() or delta <= 0.0:
        return
    elapsed += delta
    var gained = int(floor((elapsed + 0.000001) / interval))
    if gained > 0:
        charges += gained
        elapsed = max(0.0, elapsed - gained * interval)
