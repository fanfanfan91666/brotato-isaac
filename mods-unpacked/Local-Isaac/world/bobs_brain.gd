extends "res://entities/units/pet/pet.gd"

const BLAST = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const TRACKING = "item_local_isaac_bobs_brain"
var respawn_left = 0.0
var spent = false
var explosions = 0
var respawns = 0
var last_respawn_position = Vector2.ZERO
var _base_attack: WeaponStats
var _attack: WeaponStats
var last_explosion: Node
var pet_motion: Node
var curse_factor = 0.0

func _ready() -> void:
    $Contact.connect("body_entered", self, "on_contact")
    _hurtbox.set_deferred("monitoring", false)
    _animation_player.play("idle")
    pet_motion = load("res://mods-unpacked/Local-Isaac/world/pet_motion.gd").attach(self, $Animation/Sprite)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    curse_factor = curses.effect_factor(effect, player_index, "bobs_brain")
    var config = curses.params("bobs_brain", curse_factor)
    can_drop_loot = false
    _base_attack = WeaponStats.new()
    _base_attack.damage = config.damage
    _base_attack.accuracy = 1.0
    _base_attack.crit_chance = 0
    _base_attack.crit_damage = 1
    _base_attack.scaling_stats = [[Keys.stat_elemental_damage_hash, config.scaling]]
    reload_data()
    near_owner()

func should_data_be_reload() -> bool:
    return true

func reload_data() -> void:
    if _base_attack != null:
        var args = WeaponServiceInitStatsArgs.new()
        args.effects = [BLAST]
        _attack = WeaponService.init_base_stats(_base_attack, player_index, args, false, false, true)

func get_stats() -> Array:
    return [_attack]

func get_burn_damage() -> int:
    # This is pet damage: Lilith/Beast Master add the other three attack stats
    # using the same native coefficient. Ordinary characters keep Elemental.
    var coefficient = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("bobs_brain", curse_factor).burn_coefficient
    var scaling = [[Keys.stat_elemental_damage_hash, coefficient]]
    scaling = WeaponService._apply_beast_master_weapon_scaling_stat_effects(scaling, player_index)
    scaling = WeaponService._apply_weapon_scaling_stat_effects(scaling, player_index)
    var raw = int(round(max(0.0, WeaponService.sum_scaling_stat_values(scaling, player_index))))
    return WeaponService.apply_damage_bonus(raw, player_index) if raw > 0 else 0

func set_current_stats(values: Array) -> void:
    _attack = values[0]

func take_damage(_value: int, _args: TakeDamageArgs) -> Array:
    return [0, 0, false]

func near_owner() -> void:
    var owner = players_ref[player_index]
    var pos = owner.global_position + Vector2(80, 0).rotated(rand_range(-PI, PI))
    global_position = Vector2(clamp(pos.x, _min_pos.x, _max_pos.x), clamp(pos.y, _min_pos.y, _max_pos.y))

func on_contact(body: Node) -> void:
    if spent or _end_of_wave or not RunData.wave_in_progress or not body is Enemy or body.dead or body.get_charmed_by_player_index() >= 0:
        return
    spent = true
    respawn_left = 3.0
    _can_move = false
    _animation.hide()
    $Contact.set_deferred("monitoring", false)
    call_deferred("explode_now")

func explode_now() -> void:
    if _end_of_wave:
        return
    reload_data()
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = global_position
    args.damage = _attack.damage
    args.accuracy = 1.0
    args.crit_chance = 0
    args.crit_damage = 1
    args.scaling_stats = _attack.scaling_stats
    args.from_player_index = player_index
    args.from = self
    args.damage_tracking_key_hash = Keys.generate_hash(TRACKING)
    var effect = BLAST.duplicate()
    effect.scale *= 2.0
    last_explosion = WeaponService.explode(effect, args)
    var game = Utils.get_scene_node()
    var coefficient = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("bobs_brain", curse_factor).burn_coefficient
    last_explosion.connect("hit_something", game, "isaac_ipecac_explosion_hit", [{"player": player_index, "burn_damage": get_burn_damage(), "burn_scaling": coefficient, "pet_damage": true, "poison": true, "status": "IsaacIpecacPoison", "tracking": Keys.generate_hash(TRACKING)}])
    explosions += 1

func _physics_process(delta: float) -> void:
    if _end_of_wave:
        _can_move = false
        return
    if spent:
        respawn_left -= delta
        if respawn_left <= 0 and not players_ref[player_index].dead:
            near_owner()
            last_respawn_position = global_position
            respawns += 1
            spent = false
            _can_move = true
            _animation.show()
            $Contact.set_deferred("monitoring", true)

func end_of_wave_callback() -> void:
    .end_of_wave_callback()
    _can_move = false
