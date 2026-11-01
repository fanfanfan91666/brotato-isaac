extends Node2D

var system: Node
var target: Node2D
var last_target_position: Vector2
var player_index: int = 0
var speed = 900.0

func _physics_process(delta: float) -> void:
    if system.game._cleaning_up:
        queue_free()
        return
    if is_instance_valid(target) and not target.destroyed:
        last_target_position = target.global_position
    var direction = last_target_position - global_position
    if direction.length() <= max(24.0, speed * delta):
        system.detonate(last_target_position, player_index)
        queue_free()
        return
    global_position += direction.normalized() * speed * delta
    rotation += delta * 5.0
