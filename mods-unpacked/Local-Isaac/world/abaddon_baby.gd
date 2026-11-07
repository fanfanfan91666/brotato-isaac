extends "res://entities/units/pet/pet.gd"

var pet_motion: Node
var curse_factor = 0.0
var attack: RangedWeaponStats
var elapsed = 0.0
var pulses = 0
var last_visual: Node
onready var _hitbox: Hitbox = $PulseHitbox

func _ready() -> void:
    _hurtbox.set_deferred("monitoring", false)
    _animation_player.play("idle")
    pet_motion = load("res://mods-unpacked/Local-Isaac/world/pet_motion.gd").attach(self, $Animation/Sprite, true, 0.25)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    curse_factor = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").effect_factor(effect, player_index, "abaddon_baby")
    can_drop_loot = false
    _hitbox.disable()
    _hitbox.from = self
    reload_data()

func should_data_be_reload() -> bool:
    return true

func reload_data() -> void:
    var raw = RangedWeaponStats.new()
    raw.damage = 15
    raw.scaling_stats = [[Keys.stat_ranged_damage_hash, 0.5], [Keys.stat_melee_damage_hash, 0.5]]
    raw.cooldown = 180
    raw.crit_chance = 0
    var boosted = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").boost_pet_stats(raw, curse_factor)
    attack = WeaponService.init_ranged_pet_stats(boosted, player_index)

func get_stats() -> Array:
    return [attack] if attack != null else []

func set_current_stats(values: Array) -> void:
    attack = values[0]

func take_damage(_value: int, _args: TakeDamageArgs) -> Array:
    return [0, 0, false]

func _physics_process(delta: float) -> void:
    if _end_of_wave or dead or not RunData.wave_in_progress or attack == null:
        return
    elapsed += delta
    var interval = max(0.1, attack.cooldown / 60.0)
    while elapsed + 0.000001 >= interval:
        elapsed = max(0.0, elapsed - interval)
        pulse()

func pulse() -> void:
    var game = Utils.get_scene_node()
    if not game is Main or game._cleaning_up or _end_of_wave or not RunData.wave_in_progress:
        return
    _hitbox.scaling_stats = attack.scaling_stats
    _hitbox.crit_chance = attack.crit_chance
    _hitbox.crit_damage = attack.crit_damage
    _hitbox.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_abaddon_baby")
    var radius = 200.0 * load("res://mods-unpacked/Local-Isaac/pet_bonus.gd").aura_multiplier(player_index)
    for enemy in game._entity_spawner.get_all_enemies().duplicate():
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die or enemy.sleeping or enemy.get_charmed_by_player_index() >= 0 or enemy.global_position.distance_squared_to(global_position) > radius * radius:
            continue
        var args = TakeDamageArgs.new(player_index, _hitbox)
        var taken = enemy.take_damage(attack.damage, args)
        RunData.add_tracked_value(player_index, Keys.generate_hash("item_local_isaac_abaddon_baby"), taken[1])
    last_visual = load("res://mods-unpacked/Local-Isaac/world/aquarius_wave.gd").new()
    last_visual.radius = radius
    last_visual.tint = Color(0.0, 0.0, 0.0)
    game.add_child(last_visual)
    last_visual.global_position = global_position
    pulses += 1
    pet_motion.pulse()

func end_of_wave_callback() -> void:
    .end_of_wave_callback()
    _can_move = false
    elapsed = 0.0
