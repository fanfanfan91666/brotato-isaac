extends Node2D

var player_index = 0
var player: Player
var damage = 0
var direction = 0.0
var elapsed = 0.0
const DURATION = 0.24
const HALF_ANGLE = 1.134464

func _ready() -> void:
    global_position = player.global_position
    rotation = direction - HALF_ANGLE
    var args = Hitbox.HitboxArgs.new()
    args.crit_chance = 0.0
    args.crit_damage = 1.0
    $Hitbox.from = self
    $Hitbox.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_moms_knife")
    $Hitbox.set_damage(damage, args)
    $Hitbox.connect("hit_something", self, "on_hit")
    $Hitbox.enable()
    SoundManager.play(load("res://weapons/melee_sounds/whoosh_weapon_knife_swing_01.wav"), -8, 0.1)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player) or player.dead or not RunData.wave_in_progress:
        queue_free()
        return
    elapsed += delta
    global_position = player.global_position
    rotation = direction + lerp(-HALF_ANGLE, HALF_ANGLE, min(1.0, elapsed / DURATION))
    update()
    if elapsed >= DURATION:
        $Hitbox.active = false
        $Hitbox.disable()
        queue_free()

func _draw() -> void:
    if ProgressData.settings.visual_effects:
        var fade = clamp(1.0 - elapsed / DURATION, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 330, -0.42, 0.02, 24, Color(0.95, 0.98, 1.0, 0.28 * fade), 18.0, true)

func on_hit(thing_hit: Node, _damage_dealt: int) -> void:
    $Hitbox.ignored_objects.append(thing_hit)
