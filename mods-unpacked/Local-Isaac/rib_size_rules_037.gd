extends Reference

const CHARACTER_ID = "character_local_forgotten"
const STATE = "isaac_forgotten_melee_size_039"

static func eligible(weapon: Node) -> bool:
    if not weapon.stats is MeleeWeaponStats:
        return false
    var p = int(weapon.player_index)
    if p < 0 or p >= RunData.get_player_count():
        return false
    var character = RunData.get_player_character(p)
    return character != null and character.my_id == CHARACTER_ID

static func body_factor(weapon: Node) -> float:
    var owner = weapon._parent
    if is_instance_valid(owner) and owner.has_method("owner_player"):
        owner = owner.owner_player()
    if not is_instance_valid(owner):
        return 1.0
    # Animation/Sprite.scale contains native squash/facing animations. The
    # stable player size is separate, and never scales the weapons container.
    var factor = owner.get("isaac_body_size_factor")
    return max(0.01, float(factor)) if factor != null else 1.0

static func initialize(weapon: Node) -> Dictionary:
    var collision = weapon._hitbox.get_node("Collision")
    # Native melee hit rectangles are shared by scene instances. Own this one
    # once; subsequent changes only scale the carrier transform and reuse it.
    collision.shape = collision.shape.duplicate()
    weapon._range_shape.shape = weapon._range_shape.shape.duplicate()
    var extents = collision.shape.extents
    var to_sprite = weapon._hitbox.transform * collision.transform
    var reach = 0.0
    for x in [-1.0, 1.0]:
        for y in [-1.0, 1.0]:
            var corner = to_sprite.xform(extents * Vector2(x, y)) * weapon.sprite.scale
            reach = max(reach, corner.x)
    var state = {"base_scale": weapon.sprite.scale, "reach": reach, "factor": -1.0, "range": -1.0, "bonus": 0.0}
    weapon.set_meta(STATE, state)
    return state

static func sync(weapon: Node, force: bool = false) -> void:
    var state = weapon.get_meta(STATE) if weapon.has_meta(STATE) else initialize(weapon)
    var factor = body_factor(weapon)
    if not force and is_equal_approx(state.factor, factor) and is_equal_approx(state.range, float(weapon.current_stats.max_range)):
        return
    state.factor = factor
    state.range = float(weapon.current_stats.max_range)
    state.bonus = state.reach * (factor - 1.0)
    # Native art, custom ApprovedArt, and the real Hitbox descend from Sprite.
    # Keep native thrust/sweep displacement, action timing and stat_range intact.
    weapon.sprite.scale = state.base_scale * factor
    weapon._range_shape.shape.radius = max(1.0, state.range + Weapon.DETECTION_RANGE + state.bonus)

static func attack_range(weapon: Node) -> float:
    sync(weapon)
    return max(float(weapon.current_stats.min_range), weapon.current_stats.max_range + 50.0 + weapon.get_meta(STATE).bonus)

static func should_attack(weapon: Node) -> bool:
    var reach = attack_range(weapon)
    # Same native cooldown, movement and manual-aim gates. Only the additional
    # physical reach of the larger rectangle extends automatic attack distance.
    return not weapon._is_shooting and weapon._current_cooldown <= 0 and (
        weapon._parent._current_movement == Vector2.ZERO
        or RunData.get_player_effect(Keys.can_attack_while_moving_hash, weapon.player_index)
    ) and (
        (weapon._current_target.size() > 0
        and is_instance_valid(weapon._current_target[0])
        and Utils.is_between(weapon._current_target[1], weapon.current_stats.min_range, reach))
        or (weapon._manual_aim and not weapon._parent.cleaning_up)
    )
