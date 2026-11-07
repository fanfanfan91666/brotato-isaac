extends "res://entities/units/enemies/enemy.gd"

var isaac_poison_generation = 0
var isaac_petrify_status: Node = null
var isaac_fear_status: Node = null
var isaac_was_charmed_on_death = false

func isaac_movement_blocked() -> bool:
    return (is_instance_valid(isaac_petrify_status) and isaac_petrify_status.active()) or (is_instance_valid(isaac_fear_status) and isaac_fear_status.active())

func get_move_speed() -> float:
    if isaac_movement_blocked():
        return 0.0
    return .get_move_speed()

func get_next_velocity() -> Vector2:
    if isaac_movement_blocked():
        knockback_vector = Vector2.ZERO
        return Vector2.ZERO
    return .get_next_velocity()

func isaac_clear_petrify() -> void:
    if isaac_petrify_status != null and is_instance_valid(isaac_petrify_status):
        isaac_petrify_status.clear()
    isaac_petrify_status = null

func isaac_clear_fear() -> void:
    if is_instance_valid(isaac_fear_status):
        isaac_fear_status.clear()
    isaac_fear_status = null

func isaac_apply_poison(data: Dictionary, generation: int) -> void:
    if generation == isaac_poison_generation:
        load("res://mods-unpacked/Local-Isaac/poison_rules.gd").apply_now(self, data)

func respawn() -> void:
    isaac_was_charmed_on_death = false
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_charm(self)
    isaac_clear_petrify()
    isaac_clear_fear()
    isaac_clear_eyeshadow()
    isaac_poison_generation += 1
    load("res://mods-unpacked/Local-Isaac/poison_rules.gd").clear(self)
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_status(self)
    var slow = get_node_or_null("IsaacAquariusSlow")
    if slow != null:
        slow.clear()
    .respawn()

func die(args: Entity.DieArgs = Utils.default_die_args) -> void:
    isaac_was_charmed_on_death = get_charmed_by_player_index() >= 0
    isaac_clear_petrify()
    isaac_clear_fear()
    isaac_clear_eyeshadow()
    isaac_poison_generation += 1
    load("res://mods-unpacked/Local-Isaac/poison_rules.gd").clear(self)
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_status(self)
    var slow = get_node_or_null("IsaacAquariusSlow")
    if slow != null:
        slow.clear()
    .die(args)

func free_entity() -> void:
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_charm(self)
    isaac_clear_petrify()
    isaac_clear_fear()
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_status(self)
    .free_entity()

func isaac_clear_eyeshadow() -> void:
    var behavior = effect_behaviors.get_node_or_null("IsaacEyeshadowCharm") if effect_behaviors != null else null
    if behavior != null:
        behavior.uncharm()

func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: bool = true, dodgeable: bool = true, is_crit: bool = false, hitbox: Hitbox = null, is_burning: bool = false) -> Unit.GetDamageValueResult:
    var result = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)
    # Mod Loader parses every extension before installing the Unit base patch.
    call("isaac_apply_final_pet_damage", result, from_player_index, hitbox, is_burning)
    # Apply once after native armor, HP bonuses and the existing final pet
    # multiplier. Direct hits, explosions and damage-over-time use this path.
    if result.value > 0 and is_instance_valid(isaac_fear_status) and isaac_fear_status.active():
        result.value = int(round(result.value * 1.3))
    return result
