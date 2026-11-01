extends "res://weapons/shooting_behaviors/melee_weapon_shooting_behavior.gd"

const ISAAC_PROCS = preload("res://mods-unpacked/Local-Isaac/attack_rules.gd")
var isaac_pending_blast = {}
var isaac_blast_count = 0
var isaac_last_blast: Node
var isaac_pickaxe_pending = {}
var isaac_pickaxe_blast_count = 0
var isaac_pickaxe_last_blast: Node
var isaac_data_hack_pending = {}

func shoot(distance: float) -> void:
    var isaac_forced_outcome = -1
    if OS.is_debug_build() and DebugService.disable_saving and _parent.has_meta("isaac_data_hack_forced_outcome"):
        isaac_forced_outcome = int(_parent.get_meta("isaac_data_hack_forced_outcome"))
        _parent.remove_meta("isaac_data_hack_forced_outcome")
    isaac_data_hack_pending = load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").begin_attack(_parent, isaac_forced_outcome)
    var state = ISAAC_PROCS.roll(_parent)
    var utility = load("res://mods-unpacked/Local-Isaac/new_items_019.gd").roll(_parent.player_index) if _parent._parent is Player else {}
    load("res://mods-unpacked/Local-Isaac/world/fear_041.gd").roll(_parent, utility)
    load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").add_rib_clear(_parent, utility)
    load("res://mods-unpacked/Local-Isaac/world/attack_utility.gd").attach(_parent, _parent._hitbox, _parent.player_index, utility)
    _parent._hitbox.set_meta(ISAAC_PROCS.TOUGH, state.tough)
    if _parent.weapon_id == "weapon_local_isaac_broken_pickaxe":
        isaac_pickaxe_pending = load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").prepare(_parent)
    isaac_pending_blast = ISAAC_PROCS.attack_data(_parent, _parent.current_stats, state) if state.ipecac else {}
    if not _parent._hitbox.is_connected("hit_something", self, "isaac_on_melee_hit"):
        _parent._hitbox.connect("hit_something", self, "isaac_on_melee_hit")
    # Use the same motion data for both the real tween and the stats popup.
    var initial_position = _parent.sprite.position
    shooting_data = load("res://mods-unpacked/Local-Isaac/world/slow_melee_motion.gd").new(_parent.current_stats, _parent.player_index)
    _parent.set_shooting(true)
    if _parent.next_attack_type == MeleeAttackType.THRUST:
        melee_thrust_attack(initial_position)
    else:
        melee_sweep_attack(initial_position, distance)

func isaac_on_melee_hit(target: Node, _damage: int) -> void:
    if not isaac_data_hack_pending.empty():
        load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").on_hit(_parent, target, _damage, isaac_data_hack_pending, _parent._hitbox)
    if not isaac_pickaxe_pending.empty() and _damage > 0 and is_instance_valid(target):
        var pickaxe_data = isaac_pickaxe_pending
        isaac_pickaxe_pending = {}
        # One selected swing, one blast; rocks are scenery rather than Units.
        call_deferred("isaac_pickaxe_explode", target.global_position, pickaxe_data)
    if isaac_pending_blast.empty() or not target is Unit:
        return
    var data = isaac_pending_blast
    isaac_pending_blast = {}
    # A sweep can hit several units during the same physics callback.
    call_deferred("isaac_explode", target.global_position, data)

func isaac_pickaxe_explode(pos: Vector2, data: Dictionary) -> void:
    isaac_pickaxe_last_blast = load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").explode_at(pos, _parent, data)
    if isaac_pickaxe_last_blast != null:
        isaac_pickaxe_blast_count += 1

func isaac_explode(pos: Vector2, data: Dictionary) -> void:
    isaac_last_blast = ISAAC_PROCS.explode_at(pos, data)
    if isaac_last_blast != null:
        isaac_blast_count += 1
