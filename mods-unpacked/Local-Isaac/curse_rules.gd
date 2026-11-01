extends Reference

# Native DLC curse_item owns generation, wave/random coefficients, Curse stat,
# item identity and save data. Custom mechanics read the sampled item coefficient
# here rather than implementing a second curse roll or mutating shared resources.
const PREFIX = "item_local_isaac_"

static func short_name(name: String) -> String:
    return name.substr(PREFIX.length()) if name.begins_with(PREFIX) else name

static func positive_int(value: int, factor: float) -> int:
    return int(sign(value)) * int(ceil(abs(value) * (1.0 + max(0.0, factor))))

static func negative_int(value: int, factor: float) -> int:
    return int(sign(value)) * int(max(1.0, floor(abs(value) / (1.0 + max(0.0, factor))))) if value != 0 else 0

static func positive(value: float, factor: float) -> float:
    return value * (1.0 + max(0.0, factor))

static func item_factor(item) -> float:
    return max(0.0, float(item.curse_factor)) if item != null and item.is_cursed else 0.0

static func effect_factor(effect, player_index: int = -1, name: String = "") -> float:
    var sampled = max(0.0, float(effect.curse_factor))
    if sampled > 0.0:
        return sampled
    if player_index < 0 or player_index >= RunData.get_player_count():
        return 0.0
    var items = RunData.get_player_items(player_index)
    # This also recovers old non-pet effects when a caller holds the actual
    # inventory effect resource rather than its independent runtime copy.
    for item in items:
        if item.effects.has(effect):
            return item_factor(item)
    if effect.get("is_cursed") != true:
        return 0.0
    # Native JSON restoration creates stat_pets effects independently from
    # item.effects. Legacy 0.14 effects contain no coefficient, but both arrays
    # retain acquisition order. Match the same pet's occurrence rather than
    # assigning every differently cursed Bob the strongest owner's coefficient.
    var candidates = []
    for item in items:
        if name != "" and item.my_id != PREFIX + short_name(name):
            continue
        for owned_effect in item.effects:
            if same_pet_signature(effect, owned_effect):
                candidates.append(item_factor(item))
    var ordinal = 0
    for runtime_effect in RunData.players_data[player_index].effects.get(Keys.stat_pets_hash, []):
        if same_pet_signature(effect, runtime_effect):
            if runtime_effect == effect:
                return float(candidates[ordinal]) if ordinal < candidates.size() else 0.0
            ordinal += 1
    # A detached third-party copy can only be attributed when unambiguous.
    if candidates.size() == 1:
        return float(candidates[0])
    return 0.0

static func same_pet_signature(first, second) -> bool:
    if first == null or second == null:
        return false
    var first_scene = first.get("scene")
    var second_scene = second.get("scene")
    return first_scene != null and second_scene != null and first.key == second.key and first_scene.resource_path == second_scene.resource_path and first.get("is_cursed") == second.get("is_cursed")

static func params(name: String, factor: float = 0.0) -> Dictionary:
    var f = max(0.0, factor)
    match short_name(name):
        "gemini": return {"copies": positive_int(1, f)}
        "dressed_boy": return {"points": positive_int(8, f)}
        "moms_eyeshadow": return {"chance": positive_int(2, f) / 100.0, "per_luck": positive(0.0005, f), "cap": positive_int(10, f) / 100.0, "duration": positive(8.0, f)}
        "lost_contact": return {"chance": positive_int(2, f) / 100.0, "per_luck": positive(0.001, f), "cap": min(1.0, positive_int(20, f) / 100.0)}
        "scorpio": return {"damage": positive_int(3, f), "scaling": positive(1.0, f), "ticks": positive_int(3, f), "spread": positive_int(1, f), "interval": 0.5}
        "aquarius": return {"interval": 5.0, "radius": positive(200.0, f), "slow_percent": min(100, positive_int(50, f)), "slow_duration": positive(2.0, f), "knockback": positive(30.0, f)}
        "taurus": return {"speed_step": positive_int(1, f), "speed_cap": positive_int(20, f), "invincible_duration": positive(10.0, f)}
        "aries": return {"speed_threshold": negative_int(25, f), "charges": positive_int(1, f)}
        "cancer": return {"damage_taken_percent": negative_int(50, f), "health_threshold": 50}
        "virgo": return {"iframe_multiplier": 1.0 + positive_int(100, f) / 100.0}
        "d6": return {"chance": positive(0.5, f)}
        "mr_bomb": return {"amount": positive_int(5, f)}
        "bomb_bogo": return {"amount": positive_int(2, f)}
        # Preserve the user's existing explicit cursed Mom's Knife rule.
        "moms_knife": return {"damage_multiplier": 4 if f > 0 else 2, "attacks": 12, "cooldown": 0.3}
        "holy_wafer": return {"damage_taken_percent": negative_int(50, f)}
        "light_crown": return {"full_damage": positive_int(40, f), "damaged_damage": positive_int(20, f)}
        "money_equals_power": return {"gold_step": 30, "damage": positive_int(1, f)}
        "soy_milk": return {"damage_factor": 1.0 - negative_int(70, f) / 100.0}
        "polyphemus": return {"attack_speed_factor": 1.0 - negative_int(70, f) / 100.0}
        "double_vision": return {"projectiles": positive_int(1, f)}
        "eight_inch_nails": return {"base_chance": positive_int(1, f) / 100.0, "luck_chance": positive(0.0005, f), "knockback": positive_int(3, f)}
        "tough_love": return {"base_chance": positive_int(5, f) / 100.0, "luck_chance": positive(0.001, f), "damage_multiplier": 2}
        "ipecac": return {"attacks": negative_int(10, f), "damage_factor": 1.0, "burn_coefficient": 0.5, "duration": 5}
        "bobs_brain": return {"damage": positive_int(20, f), "scaling": positive(1.0, f), "burn_coefficient": positive(0.2, f), "respawn": 3.0}
        "rainbow_baby": return {"burn_coefficient": positive(0.1, f), "duration": 3}
        "succubus": return {"damage": positive_int(5, f), "interval": 5.0}
        "best_friends_forever": return {"damage_multiplier": 1.0 + positive_int(100, f) / 100.0, "body_scale": 1.5}
    # Qualitative toggles (e.g. Rock Bottom) and topology such as strictly
    # infinite penetration stay qualitative; ordinary Effect values are handled
    # directly by native curse_item and must not be boosted a second time.
    return {}

static func sum_value(name: String, player_index: int, field: String, fallback: float = 0.0) -> float:
    var result = 0.0
    if player_index < 0 or player_index >= RunData.get_player_count():
        return result
    if RunData.get_nb_item(Keys.generate_hash(PREFIX + short_name(name)), player_index) <= 0:
        return result
    for item in RunData.get_player_items(player_index):
        if item.my_id == PREFIX + short_name(name):
            result += float(params(name, item_factor(item)).get(field, fallback))
    return result

static func max_value(name: String, player_index: int, field: String, fallback: float = 0.0) -> float:
    var result = fallback
    if player_index < 0 or player_index >= RunData.get_player_count():
        return result
    if RunData.get_nb_item(Keys.generate_hash(PREFIX + short_name(name)), player_index) <= 0:
        return result
    for item in RunData.get_player_items(player_index):
        if item.my_id == PREFIX + short_name(name):
            result = max(result, float(params(name, item_factor(item)).get(field, fallback)))
    return result

static func min_value(name: String, player_index: int, field: String, fallback: float) -> float:
    var result = fallback
    if player_index < 0 or player_index >= RunData.get_player_count():
        return result
    if RunData.get_nb_item(Keys.generate_hash(PREFIX + short_name(name)), player_index) <= 0:
        return result
    for item in RunData.get_player_items(player_index):
        if item.my_id == PREFIX + short_name(name):
            result = min(result, float(params(name, item_factor(item)).get(field, fallback)))
    return result

static func owned_probability(name: String, player_index: int, luck: float) -> float:
    return clamp(sum_value(name, player_index, "base_chance") + luck * sum_value(name, player_index, "luck_chance"), 0.0, 1.0)

static func boost_pet_stats(stats: WeaponStats, factor: float) -> WeaponStats:
    if factor <= 0.0:
        return stats
    var result = stats.duplicate()
    # Live copied weapons can carry private computed fields in a temporary
    # Stats subclass (e.g. Polyphemus melee motion). Resource.duplicate only
    # guarantees storage properties; keep the already computed script fields.
    for property in stats.get_property_list():
        if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "script":
            var value = stats.get(property.name)
            result.set(property.name, value.duplicate(true) if value is Array or value is Dictionary else value)
    for key in stats.get_meta_list():
        result.set_meta(key, stats.get_meta(key))
    # Same transform as DLC1._boost_weapon_stats_damage/_boost_scaling_sats.
    result.damage = positive_int(stats.damage, factor)
    result.scaling_stats = stats.scaling_stats.duplicate(true)
    for row in result.scaling_stats:
        row[1] *= 1.0 + factor
    result.crit_damage = stepify(stats.crit_damage * (1.0 + factor / 5.0), 0.1)
    if stats.lifesteal > 0:
        result.lifesteal = stepify(stats.lifesteal * (1.0 + factor), 0.01)
    if result is RangedWeaponStats:
        if stats.piercing > 0:
            result.piercing = int(min(stats.piercing + 1, ceil(stats.piercing * (1.0 + factor / 5.0))))
        if stats.bounce > 0:
            result.bounce = int(min(stats.bounce + 1, ceil(stats.bounce * (1.0 + factor / 5.0))))
    return result

static func stamp_native_result(original, result) -> void:
    if original == null or original.is_cursed or not result.my_id.begins_with(PREFIX):
        return
    # ItemParentData.curse_factor and Effect.curse_factor are both native saved
    # fields. No metadata-only config or effect string dictionary is required.
    for effect in result.effects:
        effect.curse_factor = result.curse_factor
