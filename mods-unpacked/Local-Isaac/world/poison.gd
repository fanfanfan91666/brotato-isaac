extends Node

const FIRE = preload("res://particles/burning/unit_burning_particles.tscn")
const RULES = preload("res://mods-unpacked/Local-Isaac/poison_rules.gd")
var target: Node
var game: Node
var damage = 0
var owner_index = -1
var remaining_ticks = 0
var spread_remaining = 0
var interval = 0.5
var tick_elapsed = 0.0
var spread_elapsed = 0.0
var total_ticks = 0
var source_ref: WeakRef
var game_ref: WeakRef
var fire: Node
var finished = false

func refresh(data: Dictionary) -> void:
    # As with native burning, a weaker hit cannot overwrite stronger poison,
    # and refreshing duration does not postpone the already-running tick.
    if int(data.damage) >= damage:
        damage = int(data.damage)
        owner_index = int(data.owner)
        source_ref = data.source
    remaining_ticks = int(max(remaining_ticks, int(data.ticks)))
    spread_remaining = int(max(spread_remaining, int(data.spread)))
    interval = float(data.interval)
    game_ref = data.game
    if is_instance_valid(fire) and spread_remaining > 0:
        fire.get_node("SpreadArea").set_deferred("monitoring", true)
        fire.activate_spread()

func _ready() -> void:
    target = get_parent()
    game = game_ref.get_ref()
    if not valid_life():
        finish()
        return
    fire = FIRE.instance()
    fire.name = "IsaacPoisonParticles"
    # Both ramps are private resources. Changing poison cannot recolor the
    # original fire or another enemy's particles. Native spread is disabled.
    RULES.color_particles(fire)
    var data = BurningData.new()
    data.scaling_stats = [[Keys.stat_elemental_damage_hash, 1.0]]
    data.spread = 0
    fire.burning_data = data
    # Keep the native 128-radius overlap collection, but its automatic burn
    # transfer is inert because burning_data.spread always remains zero.
    fire.get_node("SpreadArea").monitoring = spread_remaining > 0
    fire.get_node("SpreadArea/CollisionShape2D").disabled = spread_remaining <= 0
    target.add_child(fire)
    fire.position = Vector2(0, -24)
    fire.start_emitting()

func valid_life() -> bool:
    return is_instance_valid(target) and not target.dead and not target._pending_die and not target.sleeping and is_instance_valid(game) and game == Utils.get_scene_node() and RunData.wave_in_progress and not game._cleaning_up

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if finished or (is_inside_tree() and get_tree().paused):
        return
    if not valid_life():
        finish()
        return
    tick_elapsed += max(0.0, delta)
    spread_elapsed += max(0.0, delta)
    if spread_remaining > 0 and spread_elapsed >= 0.1:
        spread_elapsed = 0.0
        spread_once()
    while not finished and remaining_ticks > 0 and tick_elapsed + 0.000001 >= interval:
        tick_elapsed = max(0.0, tick_elapsed - interval)
        remaining_ticks -= 1
        total_ticks += 1
        var args = TakeDamageArgs.new(owner_index)
        args.armor_applied = false
        args.dodgeable = false
        args.base_effect_scale = 0.1
        # Deliberately leave is_burning false: poison does not receive Greek
        # Fire or activate effects that specifically require a burning enemy.
        var taken = target.take_damage(damage, args)
        RunData.add_tracked_value(owner_index, Keys.generate_hash(RULES.ITEM), taken[1])
        var source = source_ref.get_ref() if source_ref != null else null
        if is_instance_valid(source) and source.has_method("on_weapon_hit_something"):
            source.on_weapon_hit_something(target, taken[1], null)
        if not valid_life():
            finish()
            return
    if remaining_ticks <= 0:
        finish()

func spread_once() -> void:
    # Native Snake transfers its budget to one neighbour and consumes the
    # source's budget. Already-poisoned neighbours are skipped, so two statuses
    # cannot bounce between each other and refresh forever.
    for body in fire.bodies:
        if not is_instance_valid(body) or body == target or not body is Enemy or body.dead or body._pending_die:
            continue
        var existing = body.get_node_or_null(RULES.STATUS)
        if existing != null and not existing.is_queued_for_deletion() and not existing.finished:
            continue
        var data = {"owner": owner_index, "damage": damage, "ticks": remaining_ticks, "spread": spread_remaining - 1, "interval": interval, "source": source_ref, "game": game_ref}
        if RULES.apply_now(body, data) != null:
            spread_remaining = 0
            fire.deactivate_spread()
            fire.get_node("SpreadArea").set_deferred("monitoring", false)
            break

func finish() -> void:
    if finished:
        return
    finished = true
    remaining_ticks = 0
    spread_remaining = 0
    set_physics_process(false)
    if is_instance_valid(fire):
        fire.stop_emitting()
        fire.queue_free()
    # Free only our status and particles; native burn keeps its own timer,
    # particle instance, source owner and all of its remaining damage ticks.
    name = "IsaacPoisonExpired"
    queue_free()
