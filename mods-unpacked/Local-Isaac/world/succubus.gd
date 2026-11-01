extends "res://entities/units/pet/pet.gd"

# Reuse the native Moth's Area, shader and particles without its healing effects.
const NATIVE_MOTH = preload("res://entities/units/pet/doc_moth/doc_moth.tscn")
const INTERVAL = 5.0
const DAMAGE_PER_INTERVAL = 5
var boost_zone: Area2D
var inside_owner = false
var aura_progress = 0.0
var boosts_granted = 0
var pet_motion: Node
var curse_factor = 0.0

func _ready() -> void:
    _hurtbox.set_deferred("monitoring", false)
    _animation_player.play("idle")
    var moth = NATIVE_MOTH.instance()
    boost_zone = moth.get_node("BoostZone").duplicate(14)
    moth.free()
    add_child(boost_zone)
    boost_zone.name = "BoostZone"
    boost_zone.modulate.a = ProgressData.settings.pet_opacity
    boost_zone.get_node("aura").modulate = Color(1.0, 0.08, 0.12, 0.352941)
    boost_zone.connect("body_entered", self, "on_aura_entered")
    boost_zone.connect("body_exited", self, "on_aura_exited")
    var motion_path = "res://mods-unpacked/Local-Isaac/world/pet_motion.gd"
    if ResourceLoader.exists(motion_path):
        pet_motion = load(motion_path).attach(self, $Animation/Sprite, true, 0.35)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    curse_factor = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").effect_factor(effect, player_index, "succubus")
    can_drop_loot = false

func reset_speed_stat(percent_modifier: int = 0) -> void:
    .reset_speed_stat(percent_modifier)
    current_stats.speed *= 1.5
    max_stats.speed = current_stats.speed

func take_damage(_value: int, _args: TakeDamageArgs) -> Array:
    return [0, 0, false]

func on_aura_entered(body: Node) -> void:
    if body is Player and body.player_index == player_index:
        inside_owner = true

func on_aura_exited(body: Node) -> void:
    if body is Player and body.player_index == player_index:
        inside_owner = false
        aura_progress = 0.0

func _physics_process(delta: float) -> void:
    if _end_of_wave or dead or not RunData.wave_in_progress:
        return
    boost_zone.get_node("aura").rotation += TAU * delta / 4.0
    if not inside_owner or player_index >= players_ref.size():
        return
    var player = players_ref[player_index]
    if not is_instance_valid(player) or player.dead:
        return
    advance_aura(delta)

func advance_aura(delta: float) -> void:
    aura_progress += delta
    while aura_progress + 0.000001 >= INTERVAL:
        aura_progress = max(0.0, aura_progress - INTERVAL)
        TempStats.add_stat(Keys.stat_percent_damage_hash, damage_per_interval(), player_index)
        boosts_granted += 1
        if pet_motion != null:
            pet_motion.pulse(0.0)

func damage_per_interval() -> int:
    var base = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("succubus", curse_factor).damage
    return int(round(base * load("res://mods-unpacked/Local-Isaac/pet_bonus.gd").multiplier(player_index)))

func end_of_wave_callback() -> void:
    .end_of_wave_callback()
    _can_move = false
    inside_owner = false
    aura_progress = 0.0
    if boost_zone != null:
        boost_zone.set_deferred("monitoring", false)

func _update_transparency(value) -> void:
    ._update_transparency(value)
    if boost_zone != null:
        boost_zone.modulate.a = value
