extends Reference

const ITEM = "item_local_isaac_scorpio"
const STATUS = "IsaacPoison"
const SPREAD_RADIUS = 128.0

# An independent status: poison never writes Unit._burning or is_burning.
static func attack_stats(p: int, factor: float = 0.0) -> WeaponStats:
    var config = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("scorpio", factor)
    var result = WeaponStats.new()
    result.scaling_stats = WeaponService._apply_weapon_scaling_stat_effects([[Keys.stat_elemental_damage_hash, config.scaling]], p)
    var damage = WeaponService.apply_scaling_stats_to_damage(config.damage, result.scaling_stats, p)
    result.damage = WeaponService.apply_damage_bonus(damage, p)
    return result

static func weapon_hit(target: Node, weapon: Weapon, hitbox: Hitbox) -> void:
    if not is_instance_valid(target) or not target is Enemy or target.dead or target._pending_die:
        return
    if hitbox == null or hitbox.is_healing or not is_instance_valid(weapon):
        return
    # Copied weapons belong to a Pet, not to a player's equipped weapon slot.
    if not is_instance_valid(weapon._parent) or not weapon._parent is Player:
        return
    var p = weapon.player_index
    if p < 0 or p >= RunData.get_player_count() or RunData.get_nb_item(Keys.generate_hash(ITEM), p) <= 0:
        return
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var factor = 0.0
    for item in RunData.get_player_items(p):
        if item.my_id == ITEM:
            factor = max(factor, curses.item_factor(item))
    var config = curses.params("scorpio", factor)
    var data = {"owner": p, "damage": attack_stats(p, factor).damage, "ticks": int(config.ticks), "spread": int(config.spread), "interval": float(config.interval), "source": weakref(weapon), "game": weakref(Utils.get_scene_node())}
    # Weapon hit signals can originate in a physics query. Create particle
    # Areas only after that query, and reject hits from a previous pooled life.
    target.call_deferred("isaac_apply_poison", data, target.isaac_poison_generation)

static func apply_now(target: Node, data: Dictionary) -> Node:
    if not is_instance_valid(target) or target.dead or target._pending_die or target.sleeping or target.get_charmed_by_player_index() >= 0:
        return null
    var game = data.game.get_ref()
    if not is_instance_valid(game) or game != Utils.get_scene_node() or not RunData.wave_in_progress or game._cleaning_up:
        return null
    var status = target.get_node_or_null(STATUS)
    if status != null and not status.is_queued_for_deletion() and not status.finished:
        status.refresh(data)
        return status
    status = load("res://mods-unpacked/Local-Isaac/world/poison.gd").new()
    status.name = STATUS
    status.refresh(data)
    target.add_child(status)
    return status

static func clear(target: Node) -> void:
    for status_name in [STATUS, "IsaacIpecacPoison", "IsaacBabyPoison"]:
        var status = target.get_node_or_null(status_name)
        if status != null and not status.is_queued_for_deletion():
            status.finish()

static func color_particles(fire: Node) -> void:
    fire.red_gradient = green_ramp(fire.red_gradient)
    fire.red_gradient_secondary = green_ramp(fire.red_gradient_secondary)
    var secondary = fire.get_node("secondaryParticle")
    secondary.color_initial_ramp = green_ramp(secondary.color_initial_ramp)

static func green_ramp(original: Gradient) -> Gradient:
    var result = original.duplicate()
    for i in range(result.get_point_count()):
        var color = result.get_color(i)
        result.set_color(i, Color(color.g * 0.45, color.r, color.b + color.g * 0.2, color.a))
    return result
