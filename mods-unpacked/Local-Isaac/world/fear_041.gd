extends Node

const NODE_NAME = "IsaacFear"
const EFFECT_KEY = "effect_local_isaac_weapon_fear"
const DARK_MATTER_CACHE = "isaac_dark_matter_config_0412"
const DURATION = 2.0
const TINT = Color(0.54, 0.25, 0.72, 0.65)

var target: Node
var game: Node
var remaining = 0.0
var disposed = false
var base_material: Material = null
var tinted_material: ShaderMaterial = null

static func roll(weapon: Node, utility: Dictionary) -> void:
    # Shooting behaviors call this once before producing the entire volley or
    # melee swing. Other item/weapon procs keep their own independent rolls.
    var weapon_fear = false
    var has_fear = false
    for effect in weapon.effects:
        if effect.key == EFFECT_KEY:
            has_fear = true
            weapon_fear = Utils.get_chance_success(clamp(float(effect.value) / 100.0, 0.0, 1.0))
            break
    var dark_fear = false
    var p = weapon.player_index
    if weapon._parent is Player and p >= 0 and p < RunData.get_player_count() and RunData.get_nb_item(Keys.generate_hash("item_local_isaac_dark_matter"), p) > 0:
        var values = dark_matter_config(p)
        if not values.empty():
            has_fear = true
            var chance = float(values.base_chance) + Utils.get_stat(Keys.stat_luck_hash, p) * float(values.luck_chance)
            dark_fear = Utils.get_chance_success(clamp(chance, 0.0, float(values.cap)))
    if has_fear:
        # Roll both sources independently, then share the result across this
        # attack's projectiles. A failed Dark Matter roll never erases a proc.
        utility["fear"] = bool(utility.get("fear", false)) or weapon_fear or dark_fear
        utility["fear_duration"] = DURATION

static func dark_matter_config(p: int) -> Dictionary:
    var scene = Utils.get_scene_node()
    if not scene is Main:
        return {}
    # Main is a battle-only owner. The cache contains numeric parameters only,
    # expires with this wave's scene, and holds no players or item resources.
    if not scene.has_meta(DARK_MATTER_CACHE):
        scene.set_meta(DARK_MATTER_CACHE, {})
    var cache = scene.get_meta(DARK_MATTER_CACHE)
    if cache.has(p):
        return cache[p]
    var result = {}
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    # Dark Matter is unique. Read its sampled curse coefficient once on this
    # player's first owned attack; later attacks read only the current Luck.
    for item in RunData.get_player_items(p):
        if item.my_id == "item_local_isaac_dark_matter":
            result = rules.params("dark_matter", rules.item_factor(item))
            break
    cache[p] = result
    return result

static func apply(enemy: Node, duration: float = DURATION) -> Node:
    if not is_instance_valid(enemy) or enemy.get("enemy_id") == null or enemy.dead or enemy._pending_die or enemy.sleeping or enemy.cleaning_up or duration <= 0.0 or not RunData.wave_in_progress:
        return null
    var status = enemy.get_node_or_null(NODE_NAME)
    if status == null or status.is_queued_for_deletion() or status.disposed:
        status = load("res://mods-unpacked/Local-Isaac/world/fear_041.gd").new()
        status.name = NODE_NAME
        status.target = enemy
        status.game = Utils.get_scene_node()
        status.remaining = duration
        enemy.add_child(status)
    else:
        # Reapplying fear refreshes its fixed duration; it never accumulates.
        status.remaining = duration
    enemy.isaac_fear_status = status
    enemy.knockback_vector = Vector2.ZERO
    enemy.linear_velocity = Vector2.ZERO
    enemy._integrate_forces_velocity = Vector2.ZERO
    status.sync_visual()
    return status

func _ready() -> void:
    target.connect("died", self, "on_target_died")

func active() -> bool:
    return not disposed and remaining > 0.0 and is_instance_valid(target) and not target.dead and not target._pending_die and not target.sleeping and not target.cleaning_up and is_instance_valid(game) and game.get("_cleaning_up") == false and RunData.wave_in_progress and game == Utils.get_scene_node()

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
    if active():
        load("res://mods-unpacked/Local-Isaac/world/petrify_031.gd").sync_tint(self, TINT)

func on_target_died(_enemy, _args) -> void:
    clear()

func clear() -> void:
    if disposed:
        return
    disposed = true
    remaining = 0.0
    if is_instance_valid(target):
        if target.isaac_fear_status == self:
            target.isaac_fear_status = null
        if is_instance_valid(target.sprite) and target.sprite.material == tinted_material:
            target.sprite.material = base_material
        if target._non_flash_material == tinted_material:
            target._non_flash_material = base_material
        if target.is_connected("died", self, "on_target_died"):
            target.disconnect("died", self, "on_target_died")
        # Fear has visual priority, but it never consumes the stone timer.
        var stone = target.isaac_petrify_status
        if is_instance_valid(stone) and stone.active():
            stone.sync_visual()
    name = "ExpiredFear"
    queue_free()

func _exit_tree() -> void:
    clear()
