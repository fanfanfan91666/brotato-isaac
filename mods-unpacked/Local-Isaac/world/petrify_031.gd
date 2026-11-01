extends Node

# This status only blocks the affected enemy's velocity. Native attack timers,
# animations and the rest of the game continue normally. Callers own duration;
# no weapon chance or production duration is chosen by this prototype.
const TINT_SHADER = preload("res://mods-unpacked/Local-Isaac/world/petrify_031.shader")
const NODE_NAME = "IsaacPetrify"

var target: Node
var game: Node
var remaining = 0.0
var disposed = false
var base_material: Material = null
var tinted_material: ShaderMaterial = null

static func apply(enemy: Node, duration: float) -> Node:
    if not is_instance_valid(enemy) or enemy.get("enemy_id") == null or enemy.dead or enemy._pending_die or enemy.sleeping or enemy.cleaning_up or duration <= 0.0 or not RunData.wave_in_progress:
        return null
    var status = enemy.get_node_or_null(NODE_NAME)
    if status == null or status.is_queued_for_deletion() or status.disposed:
        status = load("res://mods-unpacked/Local-Isaac/world/petrify_031.gd").new()
        status.name = NODE_NAME
        status.target = enemy
        status.game = Utils.get_scene_node()
        status.remaining = duration
        enemy.add_child(status)
    else:
        status.remaining = max(status.remaining, duration)
    enemy.isaac_petrify_status = status
    # Remove velocity left over from the physics step in which this was applied.
    # Future hits are suppressed by the Enemy.get_next_velocity integration.
    enemy.knockback_vector = Vector2.ZERO
    enemy.linear_velocity = Vector2.ZERO
    enemy._integrate_forces_velocity = Vector2.ZERO
    status.sync_visual()
    return status

static func clear_enemy(enemy: Node) -> void:
    if not is_instance_valid(enemy):
        return
    var status = enemy.get_node_or_null(NODE_NAME)
    if status != null:
        status.clear()

func _ready() -> void:
    target.connect("died", self, "on_target_died")

func active() -> bool:
    return not disposed and remaining > 0.0 and valid_target() and RunData.wave_in_progress and game == Utils.get_scene_node()

func valid_target() -> bool:
    return is_instance_valid(target) and not target.dead and not target._pending_die and not target.sleeping and not target.cleaning_up and is_instance_valid(game) and game.get("_cleaning_up") == false

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if disposed or (is_inside_tree() and get_tree().paused):
        return
    if not active():
        clear()
        return
    remaining = max(0.0, remaining - max(0.0, delta))
    if remaining <= 0.0:
        clear()
        return
    sync_visual()

func sync_visual() -> void:
    if not active():
        return
    var fear = target.isaac_fear_status
    if is_instance_valid(fear) and fear.active():
        fear.sync_visual()
        return
    sync_tint(self, Color(0.46, 0.32, 0.18, 0.65))

static func sync_tint(status: Node, color: Color) -> void:
    var enemy = status.target
    var sprite = enemy.sprite
    # Change the material saved below a native white flash, preserving the
    # flash itself and its timer while fear/petrify priorities change.
    var flashing = sprite.material == enemy.flash_mat
    var material = enemy._non_flash_material if flashing else sprite.material
    if status.tinted_material != null and material == status.tinted_material:
        return
    # Never nest one control tint inside another: either timer can expire
    # first, so each tint must restore the current native outline material.
    for other in [enemy.isaac_petrify_status, enemy.isaac_fear_status]:
        if is_instance_valid(other) and other != status and material == other.tinted_material:
            material = other.base_material
    status.base_material = material
    status.tinted_material = ShaderMaterial.new()
    status.tinted_material.shader = TINT_SHADER
    status.tinted_material.set_shader_param("texture_size", sprite.texture.get_size())
    status.tinted_material.set_shader_param("stone_color", color)
    # Native curse/charm/boost outlines all share this shader schema. Copy
    # current values into a private material, so other enemies never inherit it.
    if status.base_material is ShaderMaterial:
        for parameter in ["width", "alpha", "desaturation", "texture_size", "outline_color_0", "outline_color_1", "outline_color_2", "outline_color_3"]:
            var value = status.base_material.get_shader_param(parameter)
            if value != null:
                status.tinted_material.set_shader_param(parameter, value)
    if flashing:
        enemy._non_flash_material = status.tinted_material
    else:
        sprite.material = status.tinted_material

func on_target_died(_enemy, _args) -> void:
    clear()

func clear() -> void:
    if disposed:
        return
    disposed = true
    remaining = 0.0
    if is_instance_valid(target):
        if target.isaac_petrify_status == self:
            target.isaac_petrify_status = null
        if is_instance_valid(target.sprite) and target.sprite.material == tinted_material:
            target.sprite.material = base_material
        if target._non_flash_material == tinted_material:
            target._non_flash_material = base_material
        if target.is_connected("died", self, "on_target_died"):
            target.disconnect("died", self, "on_target_died")
    # Native pools can respawn a node before deferred deletion is processed.
    name = "ExpiredPetrify"
    queue_free()

func _exit_tree() -> void:
    clear()
