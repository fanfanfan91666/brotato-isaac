extends Node

const ITEM = "item_local_isaac_aquarius"
var player: Node2D
var game: Node
var elapsed = 0.0
var wave_number = -1
var pulses_fired = 0
var last_targets = []

static func attach(owner_player: Node2D) -> Node:
    var existing = owner_player.get_node_or_null("IsaacAquarius")
    if existing != null:
        return existing
    var result = load("res://mods-unpacked/Local-Isaac/world/aquarius_player.gd").new()
    result.name = "IsaacAquarius"
    result.player = owner_player
    owner_player.add_child(result)
    return result

func _ready() -> void:
    game = Utils.get_scene_node()

func enabled() -> bool:
    return is_instance_valid(player) and not player.dead and player.player_index >= 0 and player.player_index < RunData.get_player_count() and RunData.get_nb_item(Keys.generate_hash(ITEM), player.player_index) > 0

func config() -> Dictionary:
    return load("res://mods-unpacked/Local-Isaac/zodiac_rules.gd").config("aquarius", player.player_index)

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if is_inside_tree() and get_tree().paused:
        return
    if not enabled() or not RunData.wave_in_progress or not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false:
        elapsed = 0.0
        return
    if wave_number != RunData.current_wave:
        wave_number = RunData.current_wave
        elapsed = 0.0
    elapsed += max(0.0, delta)
    var interval = max(0.1, float(config().interval))
    while elapsed + 0.000001 >= interval:
        elapsed = max(0.0, elapsed - interval)
        emit_wave()

func emit_wave() -> void:
    if not enabled() or not RunData.wave_in_progress or not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false:
        return
    var values = config()
    var origin = player.global_position
    last_targets.clear()
    for enemy in game._entity_spawner.enemies.duplicate():
        if not is_instance_valid(enemy) or enemy.dead or enemy.sleeping or enemy.cleaning_up or enemy._pending_die:
            continue
        if enemy.global_position.distance_squared_to(origin) > float(values.radius) * float(values.radius):
            continue
        var direction = origin.direction_to(enemy.global_position)
        if direction == Vector2.ZERO:
            direction = Vector2.RIGHT
        # Unit.get_knockback_value retains native enemy/boss resistance.
        enemy.knockback_vector = direction * float(values.knockback)
        load("res://mods-unpacked/Local-Isaac/world/aquarius_slow.gd").apply(enemy, player.player_index, float(values.slow_percent), float(values.slow_duration))
        last_targets.append(weakref(enemy))
    pulses_fired += 1
    var visual = load("res://mods-unpacked/Local-Isaac/world/aquarius_wave.gd").new()
    visual.radius = float(values.radius)
    game.add_child(visual)
    visual.global_position = origin
