extends Reference

# Velocity steering replaces the native hundred-unit on/off switch.  The native
# owner target, pet speed calculation, collision response and animation stay in use.
const MOVING_RADIUS = 170.0
const REST_RADIUS = 120.0
const START_RADIUS = 180.0
const STOP_RADIUS = 125.0
var following = false
var velocity = Vector2.ZERO
var owner_velocity = Vector2.ZERO
var last_owner_position = Vector2.ZERO
var target_radius = REST_RADIUS
var initialized = false
var last_frame = -1

func reset(owner_position: Vector2) -> void:
    initialized = true
    last_owner_position = owner_position
    owner_velocity = Vector2.ZERO
    velocity = Vector2.ZERO
    following = false
    target_radius = REST_RADIUS
    last_frame = -1

func update(pet: Node, owner: Node2D, base_speed: float, separation: Vector2, delta: float) -> Vector2:
    if not is_instance_valid(owner) or delta <= 0:
        velocity = Vector2.ZERO
        return velocity
    if not initialized:
        reset(owner.global_position)
    var frame = Engine.get_physics_frames()
    if frame == last_frame:
        return velocity
    last_frame = frame
    var displacement = owner.global_position - last_owner_position
    last_owner_position = owner.global_position
    var observed = displacement / delta
    # A spawn/teleport is distance to catch up, not a lasting owner speed boost.
    if displacement.length() > max(80.0, base_speed * delta * 4.0):
        observed = Vector2.ZERO
    owner_velocity = owner_velocity.linear_interpolate(observed, 1.0 - exp(-12.0 * delta))
    if owner_velocity.length() < 1.0:
        owner_velocity = Vector2.ZERO
    var owner_moving = owner_velocity.length() > 15.0
    target_radius = lerp(target_radius, MOVING_RADIUS if owner_moving else REST_RADIUS, 1.0 - exp(-5.0 * delta))
    var offset = owner.global_position - pet.global_position
    var distance = offset.length()
    if not following and distance > START_RADIUS:
        following = true
    elif following and not owner_moving and distance < STOP_RADIUS:
        following = false
    var desired = Vector2.ZERO
    if following:
        # Matching the owner's velocity avoids repeatedly catching up and stopping
        # while the player walks steadily. The radial correction keeps a loose gap.
        desired = owner_velocity + offset.normalized() * (distance - target_radius) * 3.0
    desired += separation * 4.0
    var catch_up = clamp((distance - 320.0) / 400.0, 0.0, 0.6)
    var speed_limit = max(0.0, base_speed) * (1.0 + catch_up)
    if desired.length() > speed_limit:
        desired = desired.normalized() * speed_limit
    velocity = velocity.linear_interpolate(desired, 1.0 - exp(-8.0 * delta))
    if desired.length_squared() < 0.01 and velocity.length_squared() < 0.25:
        velocity = Vector2.ZERO
    return velocity
