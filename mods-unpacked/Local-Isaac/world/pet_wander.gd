extends "res://entities/units/movement_behaviors/target_rand_pos_movement_behavior.gd"

# Native random targets use sprite dimensions, which can be smaller than the
# pet's collision circle. Keep destinations reachable and recover from walls.
var safe_rect = Rect2()
var last_position = Vector2.ZERO
var has_sample = false
var stalled_seconds = 0.0

func init(parent: Node) -> Node:
    .init(parent)
    var collision = parent.get_node("Collision")
    var margin = 32.0
    if collision.shape is CircleShape2D:
        margin = max(margin, collision.shape.radius * max(abs(collision.global_scale.x), abs(collision.global_scale.y)) + 8.0)
    var zone = ZoneService.get_current_zone_rect()
    var low = Vector2(max(parent._min_pos.x, zone.position.x + margin), max(parent._min_pos.y, zone.position.y + margin))
    var high = Vector2(min(parent._max_pos.x, zone.end.x - margin), min(parent._max_pos.y, zone.end.y - margin))
    safe_rect = Rect2(low, Vector2(max(1.0, high.x - low.x), max(1.0, high.y - low.y)))
    _current_target = Vector2.ZERO
    has_sample = false
    stalled_seconds = 0.0
    return self

func get_new_target() -> Vector2:
    return Vector2(rand_range(safe_rect.position.x, safe_rect.end.x), rand_range(safe_rect.position.y, safe_rect.end.y))

func get_movement() -> Vector2:
    var position = _parent.global_position
    if has_sample and position.distance_squared_to(last_position) < 0.25 and position.distance_squared_to(_current_target) > EQUALITY_PRECISION * EQUALITY_PRECISION:
        stalled_seconds += _parent.get_physics_process_delta_time()
    else:
        stalled_seconds = 0.0
    last_position = position
    has_sample = true
    if stalled_seconds >= 0.75:
        # Turning inward also releases a pet already touching a wall in a save.
        _current_target = safe_rect.position + safe_rect.size * 0.5
        stalled_seconds = 0.0
    elif _current_target != Vector2.ZERO and not safe_rect.has_point(_current_target):
        _current_target = get_new_target()
    return .get_movement()
