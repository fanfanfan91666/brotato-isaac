extends Node

const ITEM = "item_local_isaac_leo"
const PENDING = "isaac_leo_stomp_pending"
const TREE_OWNER = "isaac_leo_owner"
const CONTACT_MARGIN = 2.0

var player: Node2D
var game: Node
var trees_stomped = 0
var rocks_stomped = 0

static func attach(owner_player: Node2D) -> Node:
    var existing = owner_player.get_node_or_null("IsaacLeoStomp")
    if existing != null:
        return existing
    var result = load("res://mods-unpacked/Local-Isaac/world/leo_stomp.gd").new()
    result.name = "IsaacLeoStomp"
    result.player = owner_player
    owner_player.add_child(result)
    return result

func _ready() -> void:
    if player == null:
        player = get_parent()
    game = Utils.get_scene_node()

func enabled() -> bool:
    return is_instance_valid(player) and not player.dead and player.player_index >= 0 and player.player_index < RunData.get_player_count() and RunData.get_nb_item(Keys.generate_hash(ITEM), player.player_index) > 0

func _physics_process(_delta: float) -> void:
    scan_nearby()

func scan_nearby() -> void:
    if not enabled() or not RunData.wave_in_progress:
        return
    if not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false:
        return
    var own_collision = player.get_node_or_null("Collision")
    if not own_collision is CollisionShape2D:
        return
    for tree in game._entity_spawner.neutrals.duplicate():
        if is_live_tree(tree):
            queue_contact(tree, own_collision, tree.get_node_or_null("Collision"), false)
    var system = game.get("isaac_bomb_system")
    if is_instance_valid(system):
        for rock in system.rocks.duplicate():
            if is_instance_valid(rock) and not rock.destroyed:
                queue_contact(rock, own_collision, rock.get_node_or_null("CollisionShape2D"), true)

func is_live_tree(tree) -> bool:
    return load("res://mods-unpacked/Local-Isaac/scenery_rules_032.gd").is_tree(tree) and not tree.dead and not tree.sleeping and not tree._pending_die

func circle_radius(collision: CollisionShape2D) -> float:
    if collision.shape is CircleShape2D:
        return collision.shape.radius * max(abs(collision.global_scale.x), abs(collision.global_scale.y))
    return 0.0

func queue_contact(target, own_collision: CollisionShape2D, target_collision, rock: bool) -> void:
    if target.has_meta(PENDING) or not target_collision is CollisionShape2D or target_collision.disabled:
        return
    var own_radius = circle_radius(own_collision)
    var target_radius = circle_radius(target_collision)
    if own_radius <= 0 or target_radius <= 0:
        return
    var contact_distance = own_radius + target_radius + CONTACT_MARGIN
    if own_collision.global_position.distance_squared_to(target_collision.global_position) > contact_distance * contact_distance:
        return
    # All co-op components share this reservation on the actual scenery node.
    target.set_meta(PENDING, true)
    call_deferred("stomp", target, rock)

func stomp(target, rock: bool) -> void:
    if not is_instance_valid(target):
        return
    if not enabled() or not RunData.wave_in_progress or not is_instance_valid(game) or game != Utils.get_scene_node() or game.get("_cleaning_up") != false:
        target.remove_meta(PENDING)
        return
    if rock:
        if not target.destroyed:
            rocks_stomped += 1
            # Reuse the established rewards path; this does not launch a bomb,
            # create an explosion, or debit the player's bomb stock.
            target.break_from_bomb(player.player_index)
    elif is_live_tree(target):
        trees_stomped += 1
        target.set_meta(TREE_OWNER, player.player_index)
        target.current_stats.health = 0
        target._pending_die = true
        # Native Neutral death keeps tree loot, Tree Turrets, kill statistics,
        # death animation and pooling. Main may copy TREE_OWNER into loot args.
        target.die()
        if is_instance_valid(target) and target.has_meta(TREE_OWNER):
            target.remove_meta(TREE_OWNER)
    if is_instance_valid(target):
        target.remove_meta(PENDING)
