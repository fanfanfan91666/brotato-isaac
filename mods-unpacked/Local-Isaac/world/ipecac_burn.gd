extends Node

const FIRE = preload("res://particles/burning/unit_burning_particles.tscn")
var target: Unit
var damage = 0
var owner_index = 0
var elapsed = 0.0
var ticks = 0
var fire: Node
var game: Node
var scaling = 0.5
var duration = 5
var pet_damage = false
var is_poison = false
var tracking_key = Keys.empty_hash
var finished = false

func _ready() -> void:
    target = get_parent()
    game = Utils.get_scene_node()
    var data = BurningData.new()
    data.chance = 1.0
    data.damage = damage
    data.duration = duration
    data.scaling_stats = [[Keys.stat_elemental_damage_hash, scaling]]
    data.from = game._players[owner_index]
    fire = FIRE.instance()
    # These timed effects never spread. Do not register an unused 128-radius
    # enemy-monitoring Area on every poisoned/burning target.
    fire.get_node("SpreadArea").monitoring = false
    fire.get_node("SpreadArea/CollisionShape2D").disabled = true
    if is_poison:
        load("res://mods-unpacked/Local-Isaac/poison_rules.gd").color_particles(fire)
    target.add_child(fire)
    fire.position = Vector2(0, -24)
    fire.burning_data = data
    fire.start_emitting()
    if not is_poison:
        target.set_burning(true)
        if target._burning == null:
            target._burning_player_index = owner_index

func refresh(amount: int, p: int, coefficient: float = 0.5, seconds: int = 5, tracking: int = Keys.empty_hash) -> void:
    if amount >= damage:
        damage = amount
        owner_index = p
        scaling = coefficient
        if tracking != Keys.empty_hash:
            tracking_key = tracking
    elapsed = 0
    ticks = 0
    duration = seconds

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if finished or (is_inside_tree() and get_tree().paused):
        return
    if not is_instance_valid(game) or game != Utils.get_scene_node():
        finish()
        return
    if target.dead or target._pending_die or target.sleeping or not RunData.wave_in_progress or game._cleaning_up:
        finish()
        return
    elapsed += delta
    while ticks < duration and elapsed >= ticks + 1.0:
        ticks += 1
        if damage > 0:
            var args = TakeDamageArgs.new(owner_index)
            args.armor_applied = false
            args.dodgeable = false
            args.is_burning = not is_poison
            args.set_meta("isaac_custom_poison" if is_poison else "isaac_custom_burn", true)
            args.set_meta("isaac_pet_tick_owner", owner_index if pet_damage else -1)
            var taken = target.take_damage(damage, args)
            if tracking_key != Keys.empty_hash and taken[1] > 0:
                RunData.add_tracked_value(owner_index, tracking_key, taken[1])
        if target.dead or target._pending_die:
            finish()
            return
    if elapsed >= duration:
        finish()

func finish() -> void:
    if finished:
        return
    finished = true
    set_physics_process(false)
    elapsed = float(duration)
    if is_instance_valid(fire):
        fire.stop_emitting()
        fire.queue_free()
    if not is_poison and is_instance_valid(target) and target._burning == null:
        var other_active = false
        for status in ["IsaacIpecacBurn", "IsaacBabyBurn", "IsaacDataHackBurn"]:
            var other = target.get_node_or_null(status)
            if other != null and other != self and not other.is_queued_for_deletion() and not other.finished:
                other_active = true
        if not other_active:
            target.set_burning(false)
    name = "IsaacDotExpired"
    queue_free()
