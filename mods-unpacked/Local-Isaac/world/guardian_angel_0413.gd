extends "res://entities/units/pet/jellyshield/jellyshield.gd"

const ITEM = "item_local_isaac_guardian_angel"
const SCENE = "res://mods-unpacked/Local-Isaac/world/guardian_angel.tscn"
const BASE_SPEED_META = "isaac_original_orbital_speed"
const OWNER_GUARDIAN_META = "isaac_guardian_angel"
const SHIELD_RADIUS = 30.0
const VISUAL_SIZE = 64.0

# This shield uses the native Jellyshield Area and trajectory, rather than
# becoming a targetable Pet or polling the scene's projectile list.
var is_pet = true
var _end_of_wave = false
var pet_motion: Node
var blocked_projectiles = 0

static func orbit_speed_multiplier(p: int) -> float:
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var bonus = rules.max_value("guardian_angel", p, "orbit_speed_percent", 0.0) + rules.max_value("best_friends_forever", p, "orbit_speed_percent", 0.0)
    return 1.0 + bonus / 100.0

static func apply_orbital_speed(orbital: Node, p: int, multiplier: float = -1.0) -> void:
    if not is_instance_valid(orbital) or not orbital is Jellyshield:
        return
    if not orbital.has_meta(BASE_SPEED_META):
        orbital.set_meta(BASE_SPEED_META, float(orbital.rotation_speed))
    var factor = orbit_speed_multiplier(p) if multiplier < 0.0 else multiplier
    orbital.rotation_speed = float(orbital.get_meta(BASE_SPEED_META)) * factor

static func apply_owner(owner_player: Player) -> Node:
    var factor = orbit_speed_multiplier(owner_player.player_index)
    owner_player.set_meta("isaac_orbit_speed_multiplier", factor)
    for shield in owner_player.jellyshields:
        apply_orbital_speed(shield, owner_player.player_index, factor)
    if RunData.get_nb_item(Keys.generate_hash(ITEM), owner_player.player_index) <= 0:
        return null
    if owner_player.has_meta(OWNER_GUARDIAN_META):
        var existing = owner_player.get_meta(OWNER_GUARDIAN_META)
        if is_instance_valid(existing) and not existing.is_queued_for_deletion():
            return existing
    var guardian = _spawn(owner_player, 0, 1)
    owner_player.set_meta(OWNER_GUARDIAN_META, guardian)
    return guardian

static func spawn_copy(owner_player: Player, index: int, total: int) -> Node:
    var guardian = _spawn(owner_player, index + 1, total + 1)
    guardian.set_meta("isaac_gemini_temporary", true)
    return guardian

static func _spawn(owner_player: Player, id: int, count: int) -> Node:
    # Native Player.init uses this untyped entity category for Jellyshields.
    # It avoids the PetEffect/target registration paths and keeps YSort order.
    var args = EntitySpawner.SpawnEntityArgs.new(owner_player.global_position, -1)
    args.player_index = owner_player.player_index
    var guardian = owner_player._entity_spawner_ref.spawn_entity(load(SCENE), args)
    guardian.init_trajectory(id, count, owner_player)
    owner_player.jellyshields.append(guardian)
    return guardian

func _ready() -> void:
    var source_size = sprite.texture.get_size()
    var factor = VISUAL_SIZE / max(source_size.x, source_size.y)
    sprite.scale = Vector2.ONE * factor
    # The shape is private even when multiple copies share this PackedScene.
    var collision = $Hurtbox/Collision
    collision.shape = collision.shape.duplicate()
    pet_motion = load("res://mods-unpacked/Local-Isaac/world/pet_motion.gd").attach(self, sprite, true, 0.28)
    get_tree().current_scene.connect("end_of_the_wave", self, "end_of_wave_callback")
    _animation_player.play("idle")

func init_trajectory(id: int, count: int, owner_player: Player) -> void:
    .init_trajectory(id, count, owner_player)
    _angle = -PI / 2.0
    apply_orbital_speed(self, player_index)
    update_bonus_size()
    update_highlight()
    update_orbit(0.0)

func update_bonus_size() -> void:
    var bonus = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd")
    var factor = 1.5 if bonus.enabled(player_index) else 1.0
    pet_motion.set_body_multiplier(factor)
    $Hurtbox/Collision.shape.radius = SHIELD_RADIUS * factor

func update_highlight(value: bool = true) -> void:
    # Native untyped shields receive the owner after _ready. Do not attach
    # player -1's cooperative outline before init_trajectory assigns ours.
    if player_index >= 0:
        .update_highlight(value)

func update_orbit(delta: float) -> void:
    _angle = fmod(_angle + delta * rotation_speed, TAU)
    global_position = _owner_player.global_position + Vector2(radius, 0).rotated(_angle + _phase)

func _physics_process(delta: float) -> void:
    if _end_of_wave or dead or not RunData.wave_in_progress:
        return
    if not is_instance_valid(_owner_player) or _owner_player.dead:
        end_of_wave_callback()
        return
    update_orbit(delta)

func _on_Hurtbox_area_entered(hitbox: Area2D) -> void:
    if _end_of_wave or dead or not RunData.wave_in_progress or not is_instance_valid(hitbox):
        return
    var projectile = hitbox.get_parent()
    if not projectile is EnemyProjectile or hitbox.get("active") != true:
        return
    blocked_projectiles += 1
    hitbox.hit_something(self, 0)
    # Some native rotating enemy bullets deliberately survive hit_something;
    # a shield must also stop those, using the projectile's normal pool path.
    if is_instance_valid(projectile) and hitbox.active:
        projectile.stop()
    pet_motion.pulse()

func end_of_wave_callback() -> void:
    _end_of_wave = true
    $Hurtbox.set_deferred("monitoring", false)
