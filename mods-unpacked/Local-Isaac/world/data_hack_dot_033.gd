extends Node

const RULES = preload("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd")
const FIRE = preload("res://particles/burning/unit_burning_particles.tscn")
var target: Node
var data = {}
var damage = 0
var remaining_ticks = 0
var elapsed = 0.0
var duration = 0
var generation = -1
var fire: Node
var finished = false
var is_poison = false

func refresh(state: Dictionary) -> void:
    if int(state.dot_damage) >= damage:
        damage = int(state.dot_damage)
        data = state.duplicate()
    remaining_ticks = max(remaining_ticks, int(state.dot_ticks))
    duration = int(state.dot_ticks)
    is_poison = int(state.outcome) == 2

func _ready() -> void:
    target = get_parent()
    generation = target.isaac_poison_generation
    if not valid_life():
        finish()
        return
    var burn = BurningData.new()
    burn.damage = damage
    burn.duration = duration
    burn.spread = 0
    burn.from = data.source.get_ref()
    fire = FIRE.instance()
    fire.burning_data = burn
    fire.get_node("SpreadArea").monitoring = false
    fire.get_node("SpreadArea/CollisionShape2D").disabled = true
    if is_poison:
        load("res://mods-unpacked/Local-Isaac/poison_rules.gd").color_particles(fire)
    target.add_child(fire)
    fire.position = Vector2(0, -24)
    fire.start_emitting()
    if not is_poison:
        target.set_burning(true)
        if target._burning == null:
            target._burning_player_index = int(data.owner)

func valid_life() -> bool:
    return RULES.valid_game(data) != null and RULES.valid_target(target, generation) and target.get_charmed_by_player_index() < 0

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if finished or (is_inside_tree() and get_tree().paused):
        return
    if not valid_life():
        finish()
        return
    elapsed += max(0.0, delta)
    while not finished and remaining_ticks > 0 and elapsed + 0.000001 >= 1.0:
        elapsed = max(0.0, elapsed - 1.0)
        remaining_ticks -= 1
        var source = data.source.get_ref()
        var args = TakeDamageArgs.new(int(data.owner))
        args.armor_applied = false
        args.dodgeable = false
        args.is_burning = not is_poison
        args.set_meta("isaac_custom_poison" if is_poison else "isaac_custom_burn", true)
        args.set_meta("isaac_pet_tick_owner", load("res://mods-unpacked/Local-Isaac/pet_bonus.gd").source_owner(source))
        var taken = target.take_damage(damage, args)
        RULES.track_damage(data, target, int(taken[1]))
        if not valid_life():
            finish()
            return
    if remaining_ticks <= 0:
        finish()

func finish() -> void:
    if finished:
        return
    finished = true
    remaining_ticks = 0
    set_physics_process(false)
    if is_instance_valid(fire):
        fire.stop_emitting()
        fire.queue_free()
    if not is_poison and is_instance_valid(target) and target._burning == null:
        var other_active = false
        for status_name in ["IsaacIpecacBurn", "IsaacBabyBurn", RULES.BURN]:
            var other = target.get_node_or_null(status_name)
            if other != null and other != self and not other.is_queued_for_deletion() and not other.finished:
                other_active = true
        if not other_active:
            target.set_burning(false)
    name = "ExpiredDataHackDot"
    queue_free()
