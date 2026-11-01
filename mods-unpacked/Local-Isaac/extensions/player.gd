extends "res://entities/units/player/player.gd"

const ISAAC_BODY = preload("res://mods-unpacked/Local-Isaac/content/characters/isaac/isaac_body_texture.tres")
const LILITH_BODY = preload("res://mods-unpacked/Local-Isaac/content/characters/lilith/lilith_body_texture.tres")
var _isaac_previous_body: Texture = null
var isaac_zodiac
var isaac_leo
var isaac_aquarius
var isaac_forgotten
var isaac_body_size_factor = 1.0

func _ready() -> void:
    connect("health_updated", self, "isaac_health_updated")
    isaac_zodiac = load("res://mods-unpacked/Local-Isaac/world/zodiac_player.gd").attach(self)
    isaac_leo = load("res://mods-unpacked/Local-Isaac/world/leo_stomp.gd").attach(self)
    isaac_aquarius = load("res://mods-unpacked/Local-Isaac/world/aquarius_player.gd").attach(self)
    isaac_forgotten = load("res://mods-unpacked/Local-Isaac/forgotten_rules.gd").attach(self)

func isaac_health_updated(_unit: Unit, _current: int, _maximum: int) -> void:
    if isaac_zodiac != null:
        isaac_zodiac.update_health(_current, _maximum)
    if RunData.get_nb_item(Keys.generate_hash("item_local_isaac_light_crown"), player_index) > 0:
        Utils.reset_stat_cache(player_index)
        RunData._are_player_stats_dirty[player_index] = true

func take_damage(value: int, args: TakeDamageArgs) -> Array:
    var healing = args.hitbox != null and args.hitbox.is_healing
    if isaac_zodiac != null and not healing:
        isaac_zodiac.prepare_hit()
        if value > 0 and isaac_zodiac.is_invulnerable():
            return [0, 0, false]
    # Use the native one-hit branch only during this damage call. Its dodge,
    # protection, armor, and positive-damage checks stay unchanged, and this
    # battle-only state never becomes a persistent RunData effect.
    var soul_hit = not healing and isaac_forgotten != null and isaac_forgotten.one_hit_active()
    var one_hit_effects = RunData.get_player_effects(player_index) if soul_hit else null
    var previous_one_hit = int(one_hit_effects[Keys.die_in_one_hit_hash]) if soul_hit else 0
    if soul_hit:
        one_hit_effects[Keys.die_in_one_hit_hash] = max(1, previous_one_hit)
    var result = .take_damage(value, args)
    if soul_hit:
        one_hit_effects[Keys.die_in_one_hit_hash] = previous_one_hit
    # A lethal hit still damages the crown when Forgotten revives to full HP.
    if int(result[1]) > 0 and RunData.get_nb_item(Keys.generate_hash("item_local_isaac_light_crown"), player_index) > 0:
        RunData.get_player_effects(player_index)[Keys.generate_hash("local_isaac_crown_damaged_wave")] = RunData.current_wave
        isaac_health_updated(self, current_stats.health, max_stats.health)
    return result

func die(args: = Utils.default_die_args) -> void:
    if isaac_forgotten != null and isaac_forgotten.try_revive(args):
        return
    .die(args)

func update_player_stats(reset_current_health: = false) -> void:
    .update_player_stats(reset_current_health)
    if isaac_forgotten != null:
        isaac_forgotten.update_body_size()

func life_bar_effects() -> Dictionary:
    var effects = .life_bar_effects()
    if isaac_forgotten != null:
        effects["isaac_forgotten_phase"] = isaac_forgotten.bar_phase()
    return effects

func apply_items_effects() -> void:
    if _isaac_previous_body != null:
        sprite.texture = _isaac_previous_body
        _isaac_previous_body = null
    load("res://mods-unpacked/Local-Isaac/head_visuals.gd").remove_legacy_face(player_index)
    .apply_items_effects()
    set_collision_mask_bit(20, true)
    var head = load("res://mods-unpacked/Local-Isaac/head_visuals.gd").body(RunData.get_player_character(player_index).my_id)
    if head != null:
        _isaac_previous_body = sprite.texture
        sprite.texture = head
        return
    if RunData.get_player_character(player_index).my_id == "character_local_isaac":
        # Keep the original Sprite node, its transforms, legs and AnimationPlayer.
        # Only the texture's logical display size is adjusted to fit the body.
        _isaac_previous_body = sprite.texture
        sprite.texture = ISAAC_BODY
    elif RunData.get_player_character(player_index).my_id == "character_local_lilith":
        _isaac_previous_body = sprite.texture
        sprite.texture = LILITH_BODY

func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: bool = true, dodgeable: bool = true, is_crit: bool = false, hitbox: Hitbox = null, is_burning: bool = false) -> Unit.GetDamageValueResult:
    if isaac_zodiac != null:
        isaac_zodiac.prepare_hit()
    var result = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)
    var factor = isaac_zodiac.damage_factor() if isaac_zodiac != null else 1.0
    if result.value > 0 and RunData.get_nb_item(Keys.generate_hash("item_local_isaac_holy_wafer"), player_index) > 0:
        var percent = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").min_value("holy_wafer", player_index, "damage_taken_percent", 50.0)
        factor *= percent / 100.0
    if result.value > 0 and factor != 1.0:
        result.value = max(1, int(ceil(result.value * factor)))
    return result

func get_iframes(damage_taken: float) -> float:
    var duration = .get_iframes(damage_taken)
    return duration * isaac_zodiac.iframe_factor() if damage_taken > 0 and isaac_zodiac != null else duration
