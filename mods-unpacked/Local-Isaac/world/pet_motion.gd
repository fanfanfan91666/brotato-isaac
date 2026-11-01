extends Node2D

var pet: Node
var body: Sprite
var is_winged = false
var wing_split = 0.35
var attack_pulse = 0.0
var shot_feedback_count = 0
var elapsed = 0.0
var pulse_left = 0.0
var pulse_direction = 0.0
var base_position = Vector2.ZERO
var base_scale = Vector2.ONE
var body_multiplier = 1.0
var base_rotation = 0.0
var collision_check = 0.0
var known_bodies = {}

static func attach(owner_pet: Node, sprite: Sprite, winged: bool = false, wing_split_ratio: float = 0.35) -> Node:
    var existing = sprite.get_node_or_null("PetMotion")
    if existing != null:
        return existing
    var result = load("res://mods-unpacked/Local-Isaac/world/pet_motion.gd").new()
    result.name = "PetMotion"
    result.pet = owner_pet
    result.body = sprite
    result.is_winged = winged
    result.wing_split = wing_split_ratio
    sprite.add_child(result)
    return result

func _ready() -> void:
    base_position = body.position
    base_scale = Vector2(abs(body.scale.x), abs(body.scale.y))
    base_rotation = body.rotation
    if is_winged and body.texture != null:
        make_wings()
    refresh_collision_exceptions()
    update_pet_bonus()

func update_pet_bonus() -> void:
    var path = "res://mods-unpacked/Local-Isaac/pet_bonus.gd"
    if ResourceLoader.exists(path):
        load(path).update_pet_visual(pet)

func set_body_multiplier(value: float) -> void:
    body_multiplier = value
    apply_body_scale()

func apply_body_scale() -> void:
    if not is_instance_valid(body):
        return
    var facing = -1.0 if body.scale.x < 0 else 1.0
    body.scale = Vector2(base_scale.x * facing * (1.0 + attack_pulse * 0.10), base_scale.y * (1.0 - attack_pulse * 0.06)) * body_multiplier

func make_wings() -> void:
    var source = body.texture
    var size = source.get_size()
    var width = int(round(size.x * clamp(wing_split, 0.2, 0.4)))
    var center = AtlasTexture.new()
    center.atlas = source
    center.region = Rect2(width, 0, size.x - 2 * width, size.y)
    body.texture = center
    for side in [-1, 1]:
        var pivot = Node2D.new()
        pivot.name = "LeftWing" if side < 0 else "RightWing"
        pivot.position.x = side * (size.x / 2.0 - width)
        add_child(pivot)
        var wing = Sprite.new()
        var atlas = AtlasTexture.new()
        atlas.atlas = source
        atlas.region = Rect2(0 if side < 0 else size.x - width, 0, width, size.y)
        wing.texture = atlas
        wing.position.x = side * width / 2.0
        pivot.add_child(wing)

func pulse(direction: float = 0.0) -> void:
    shot_feedback_count += 1
    pulse_left = 0.18
    pulse_direction = direction
    attack_pulse = 1.0

func refresh_collision_exceptions() -> void:
    var game = Utils.get_scene_node()
    if not game is Main or not pet is PhysicsBody2D:
        return
    # Keep layer 512 for native detection zones while removing physical crowding.
    pet.set_collision_mask_bit(9, false)
    var peers = game._players + game._entity_spawner.pets
    for peer in peers:
        if is_instance_valid(peer) and peer != pet and peer is PhysicsBody2D and not known_bodies.has(peer.get_instance_id()):
            pet.add_collision_exception_with(peer)
            peer.add_collision_exception_with(pet)
            known_bodies[peer.get_instance_id()] = true

func separation_vector() -> Vector2:
    var result = Vector2.ZERO
    var game = Utils.get_scene_node()
    if not game is Main:
        return result
    for peer in game._entity_spawner.pets:
        if not is_instance_valid(peer) or peer == pet or peer.dead or peer.sleeping:
            continue
        var offset = pet.global_position - peer.global_position
        var distance = offset.length()
        if distance >= 52.0:
            continue
        if distance < 0.1:
            var low = min(pet.get_instance_id(), peer.get_instance_id())
            var high = max(pet.get_instance_id(), peer.get_instance_id())
            offset = Vector2.RIGHT.rotated(deg2rad(float(int(low * 17 + high * 31) % 360)))
            if pet.get_instance_id() != low:
                offset = -offset
        result += offset.normalized() * (1.0 - distance / 52.0) * 24.0
    return result

func _physics_process(delta: float) -> void:
    if not is_instance_valid(pet) or not is_instance_valid(body) or pet.dead or pet._end_of_wave:
        return
    update_pet_bonus()
    elapsed += delta
    collision_check -= delta
    if collision_check <= 0:
        collision_check = 0.5
        refresh_collision_exceptions()
    pulse_left = max(0.0, pulse_left - delta)
    attack_pulse = sin(PI * pulse_left / 0.18) if pulse_left > 0 else 0.0
    body.position = base_position - Vector2.RIGHT.rotated(pulse_direction) * attack_pulse * 1.8
    body.rotation = base_rotation + sin(pulse_left * 90.0) * attack_pulse * 0.025
    apply_body_scale()
    if is_winged:
        var flutter = sin(elapsed * 12.0) * 0.09
        $LeftWing.rotation = flutter
        $RightWing.rotation = -flutter
        $LeftWing.scale.y = 1.0 - abs(sin(elapsed * 12.0)) * 0.06
        $RightWing.scale.y = $LeftWing.scale.y
