extends Node

const PETRIFY_LIVES = "isaac_petrify_hit_lives"

var hitbox: Hitbox
var owner_index = -1
var flags = {}
var disposed = false
var projectile: Node
var last_position = Vector2.ZERO
var game: Node

static func attach(host: Node, box: Hitbox, p: int, state: Dictionary) -> void:
    clear(host)
    if not state.get("charm", false) and not state.get("clear", false) and not state.get("petrify", false) and not state.get("fear", false):
        return
    var utility = load("res://mods-unpacked/Local-Isaac/world/attack_utility.gd").new()
    utility.name = "IsaacAttackUtility"
    utility.hitbox = box
    utility.owner_index = p
    utility.flags = state.duplicate(true)
    if state.get("petrify", false) or state.get("fear", false):
        box.set_meta(PETRIFY_LIVES, {})
    utility.projectile = host if host is Projectile else null
    host.add_child(utility)

static func clear(host: Node) -> void:
    var box = host.get("_hitbox")
    if is_instance_valid(box) and box.has_meta(PETRIFY_LIVES):
        box.remove_meta(PETRIFY_LIVES)
    var old = host.get_node_or_null("IsaacAttackUtility")
    if old != null:
        old.dispose()

func _ready() -> void:
    game = Utils.get_scene_node()
    last_position = hitbox.global_position
    var source = projectile if projectile != null else hitbox
    source.connect("hit_something", self, "on_hit")

func on_hit(target: Node, _damage: int) -> void:
    if not disposed and (flags.get("petrify", false) or flags.get("fear", false)) and _damage > 0 and target is Enemy and not target.dead and not target._pending_die:
        var lives = hitbox.get_meta(PETRIFY_LIVES) if hitbox.has_meta(PETRIFY_LIVES) else {}
        var generation = int(lives.get(target.get_instance_id(), target.isaac_poison_generation))
        if flags.get("petrify", false):
            call_deferred("petrify_enemy", weakref(target), generation, float(flags.get("petrify_duration", 2.0)))
        if flags.get("fear", false):
            call_deferred("fear_enemy", weakref(target), generation, float(flags.get("fear_duration", 2.0)))
    if disposed or not flags.get("charm", false) or not target is Enemy or target is Boss or target.dead or target._pending_die or target.is_loot or not target.can_be_charmed:
        return
    var duration = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("moms_eyeshadow", owner_index, "duration", 8.0)
    call_deferred("charm_enemy", weakref(target), target.isaac_poison_generation, duration)

func petrify_enemy(target_ref: WeakRef, generation: int, duration: float) -> void:
    var target = target_ref.get_ref()
    # Last impact can return this projectile to its pool before this callback.
    # Keep the captured duration, but never affect the next pooled enemy life.
    if not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false or not is_instance_valid(target) or target.dead or target._pending_die or target.isaac_poison_generation != generation or not RunData.wave_in_progress:
        return
    load("res://mods-unpacked/Local-Isaac/world/petrify_031.gd").apply(target, duration)

func fear_enemy(target_ref: WeakRef, generation: int, duration: float) -> void:
    var target = target_ref.get_ref()
    # The captured impact belongs to one enemy life even if another hit
    # returns that body to the pool before this deferred callback runs.
    if not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false or not is_instance_valid(target) or target.dead or target._pending_die or target.isaac_poison_generation != generation or not RunData.wave_in_progress:
        return
    load("res://mods-unpacked/Local-Isaac/world/fear_041.gd").apply(target, duration)

func charm_enemy(target_ref: WeakRef, generation: int, duration: float) -> void:
    var target = target_ref.get_ref()
    # An impact can return the projectile to its pool before this callback;
    # carry the immutable owner and flags until the deferred callback completes.
    if not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false or not is_instance_valid(target) or target.dead or target._pending_die or target.isaac_poison_generation != generation or not RunData.wave_in_progress:
        return
    apply_charm(target, owner_index, duration)

static func apply_charm(target: Node, p: int, duration: float) -> void:
    if not is_instance_valid(target) or not target is Enemy or target is Boss or target.dead or target._pending_die or target.is_loot or not target.can_be_charmed:
        return
    if target.get_charmed_by_player_index() >= 0:
        return
    var behavior = target.effect_behaviors.get_node_or_null("IsaacEyeshadowCharm")
    if behavior == null:
        behavior = load("res://mods-unpacked/Local-Isaac/world/eyeshadow_charm.tscn").instance()
        behavior.init(target)
        target.effect_behaviors.add_child(behavior)
    behavior.charm(p)
    behavior._absorb_next_damage = false
    behavior._charm_timer.start(duration)
    RunData.add_tracked_value(p, Keys.generate_hash("item_local_isaac_moms_eyeshadow"), 1)

func _physics_process(delta: float) -> void:
    if disposed or not flags.get("clear", false) or not RunData.wave_in_progress or not hitbox.active or hitbox.is_disabled():
        return
    var shape_node = hitbox.get_node_or_null("Collision")
    if not shape_node is CollisionShape2D or shape_node.disabled or shape_node.shape == null:
        return
    var current = hitbox.global_position
    var distance = current.distance_to(last_position) if projectile != null else 0.0
    var steps = int(clamp(ceil(distance / 16.0), 1, 12))
    for step in range(steps):
        var params = Physics2DShapeQueryParameters.new()
        params.set_shape(shape_node.shape)
        params.transform = shape_node.global_transform
        params.transform.origin += last_position.linear_interpolate(current, float(step + 1) / steps) - current if projectile != null else Vector2.ZERO
        params.collision_layer = Utils.ENEMY_PROJECTILES_BIT
        params.collide_with_areas = true
        params.collide_with_bodies = false
        for result in hitbox.get_world_2d().direct_space_state.intersect_shape(params, 32):
            var area = result.collider
            if not area is Hitbox or not area.active:
                continue
            var bullet = area.get_parent()
            while bullet != null and not bullet is Projectile:
                bullet = bullet.get_parent()
            if bullet != null and bullet.get_parent() != null:
                bullet.stop()
                if flags.get("track_contact", true):
                    RunData.add_tracked_value(owner_index, Keys.generate_hash("item_local_isaac_lost_contact"), 1)
    last_position = current

func dispose() -> void:
    disposed = true
    flags.clear()
    set_physics_process(false)
    name = "ExpiredAttackUtility"
    queue_free()
