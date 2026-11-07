extends Reference

# Keep player-facing language in translations, and numbers in gameplay rules.
# The three adapters preserve their native apply/unapply and serialization paths.
const PREFIX = "EFFECT_LOCAL_ISAAC_"

static func is_custom_effect(effect: Resource) -> bool:
    return effect.key.begins_with("effect_local_isaac_") or effect.key.begins_with("effect_local_forgotten_") or effect.text_key.to_upper().begins_with(PREFIX)

static func number(value, colored: bool = true) -> String:
    var result = str(stepify(float(value), 0.001))
    if colored:
        return "[color=#" + ProgressData.settings.color_positive + "]" + result + "[/color]"
    return result

static func negative_number(value, colored: bool = true) -> String:
    var result = str(stepify(float(value), 0.001))
    if colored:
        return "[color=#" + ProgressData.settings.color_negative + "]" + result + "[/color]"
    return result

static func icon(stat: int) -> String:
    var picture = ItemService.get_stat_small_icon(stat)
    if picture == null:
        return ""
    var size = 15 * ProgressData.settings.font_size
    return "[img=%sx%s]%s[/img]" % [size, size, picture.resource_path]

static func scaling_text(scaling: Array, colored: bool) -> String:
    var text = WeaponService.get_scaling_stats_icon_text(scaling)
    if not colored:
        text = strip_colors(text)
    return text

static func strip_colors(text: String) -> String:
    var tags = RegEx.new()
    tags.compile("\\[/?color(?:=[^\\]]+)?\\]")
    return tags.sub(text, "", true)

static func formula(stats: WeaponStats, colored: bool) -> String:
    var result = number(stats.damage, colored)
    if not stats.scaling_stats.empty():
        result += " (" + scaling_text(stats.scaling_stats, colored) + ")"
    return result

static func pet_attack(kind: int, mode: int, p: int, factor: float) -> RangedWeaponStats:
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var raw = load("res://mods-unpacked/Local-Isaac/baby_rules.gd").base_stats(kind, mode)
    var boosted = rules.boost_pet_stats(raw, factor)
    var args = WeaponServiceInitStatsArgs.new()
    if kind == 3 and mode == 1:
        args.effects = [load("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")]
    return WeaponService.init_ranged_pet_stats(boosted, p, false, args)

static func pet_burn(coefficient: float, p: int, colored: bool) -> String:
    var scaling = [[Keys.stat_elemental_damage_hash, coefficient]]
    scaling = WeaponService._apply_beast_master_weapon_scaling_stat_effects(scaling, p)
    scaling = WeaponService._apply_weapon_scaling_stat_effects(scaling, p)
    var raw = int(round(max(0.0, WeaponService.sum_scaling_stat_values(scaling, p))))
    var amount = WeaponService.apply_damage_bonus(raw, p) if raw > 0 else 0
    return number(amount, colored) + " (" + scaling_text(scaling, colored) + ")"

static func forgotten_size_gains(p: int) -> Array:
    if p < 0 or p >= RunData.get_player_count():
        return [0, 0]
    var character = RunData.get_player_character(p)
    if character == null or character.my_id != "character_local_forgotten":
        return [0, 0]
    var size_rules = load("res://mods-unpacked/Local-Isaac/forgotten_rules.gd")
    return [size_rules.body_size_percent(Utils.get_stat(Keys.stat_percent_damage_hash, p), 0.0), size_rules.body_size_percent(0.0, RunData.get_player_max_health(p))]

static func get_text(effect: Resource, p: int, colored: bool = true) -> String:
    var key = effect.text_key.to_upper() if effect.text_key != "" else effect.key.to_upper()
    var name = key.replace(PREFIX, "").to_lower()
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var factor = rules.effect_factor(effect, p, name)
    var config = rules.params(name, factor)
    var args = []
    match name:
        "divine_barrier":
            args = [number(config.interval, colored), number(config.charges, colored)]
        "goat_head", "duality":
            args = []
        "sin_twins":
            args = [number(config.damage_factor * 100.0, colored)]
        "bloody_gust":
            args = [number(config.speed, colored), number(config.attack_speed, colored), number(config.stacks, colored), icon(Keys.stat_speed_hash), icon(Keys.stat_attack_speed_hash)]
        "eucharist":
            args = [number(config.chance * 100.0, colored)]
        "guardian_angel":
            args = [number(config.orbit_speed_percent, colored)]
        "nightmare":
            args = [number(config.duration, colored), number(config.cooldown, colored)]
        "pound_of_flesh", "forget_me_now":
            args = []
        "lusty_blood":
            args = [number(config.kills, colored), number(config.damage, colored), icon(Keys.stat_percent_damage_hash)]
        "dark_matter":
            args = [number(config.base_chance * 100.0, colored), number(config.luck_chance * 1000.0, colored), number(config.cap * 100.0, colored), number(config.duration, colored), icon(Keys.stat_luck_hash)]
        "judas_shadow":
            args = [number(config.revives, colored), number(config.damage, colored), icon(Keys.stat_percent_damage_hash)]
        "weapon_fear":
            args = [number(min(100, effect.value), colored), number(2, colored), number(30, colored)]
        "effect_local_forgotten_body_size":
            var gains = forgotten_size_gains(p)
            args = [icon(Keys.stat_percent_damage_hash), icon(Keys.stat_max_hp_hash), number(gains[0], colored), number(gains[1], colored)]
        "effect_local_forgotten_damage_size":
            args = [icon(Keys.stat_percent_damage_hash), number(forgotten_size_gains(p)[0], colored)]
        "effect_local_forgotten_health_size":
            args = [icon(Keys.stat_max_hp_hash), number(forgotten_size_gains(p)[1], colored)]
        "boomerang_petrify":
            args = [number(min(100, effect.value), colored), number(2, colored)]
        "spirit_wave":
            args = [number(effect.value, colored), formula(load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").beam_stats(p), colored)]
        "sacrifice_curse", "sacrifice_heal":
            args = [number(effect.value, colored)]
        "nickel_coin", "rib_clear":
            args = [number(min(100, effect.value), colored)]
        "nickel_growth":
            args = [number(effect.value, colored), icon(Keys.stat_percent_damage_hash)]
        "rib_growth":
            args = [number(effect.value, colored), icon(Keys.stat_percent_damage_hash)]
        "pickaxe_growth":
            args = [number(min(100, effect.value), colored), icon(Keys.stat_percent_damage_hash)]
        "pickaxe_bomb":
            var tier = clamp(int(effect.custom_key.replace("local_isaac_pickaxe_bomb_tier_", "")) - 1, 0, 3)
            var raw = load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").raw_stats(tier, 1.0 + max(0.0, effect.curse_factor))
            var shown = raw.duplicate()
            shown.damage = WeaponService.get_explosion_damage(raw, p)
            args = [number(min(100, effect.value), colored), formula(shown, colored)]
        "gemini":
            args = [number(config.copies, colored)]
        "dressed_boy":
            var allocation = load("res://mods-unpacked/Local-Isaac/new_items_019.gd").allocation(effect, p)
            var total = 0
            for amount in allocation:
                total += int(amount)
            args = [number(total if total > 0 else config.points, colored)]
        "moms_eyeshadow", "lost_contact":
            var chance = clamp(config.chance + Utils.get_stat(Keys.stat_luck_hash, p) * config.per_luck, 0.0, config.cap)
            args = [number(chance * 100.0, colored), number(8 if name == "moms_eyeshadow" else 0, colored), number(20 if name == "moms_eyeshadow" else 10, colored), number(config.per_luck * (2000 if name == "moms_eyeshadow" else 1000), colored), number(config.cap * 100.0, colored), icon(Keys.stat_luck_hash)]
            if name == "moms_eyeshadow":
                args[1] = number(config.duration, colored)
        "abaddon_baby":
            var raw = RangedWeaponStats.new()
            raw.damage = 15
            raw.scaling_stats = [[Keys.stat_ranged_damage_hash, 0.5], [Keys.stat_melee_damage_hash, 0.5]]
            raw.cooldown = 180
            var stats = WeaponService.init_ranged_pet_stats(rules.boost_pet_stats(raw, factor), p)
            args = [formula(stats, colored), number(stats.cooldown / 60.0, colored)]
        "scorpio":
            var stats = load("res://mods-unpacked/Local-Isaac/poison_rules.gd").attack_stats(p, factor)
            args = [formula(stats, colored), number(config.ticks, colored), number(config.interval, colored), number(config.spread, colored)]
        "aquarius":
            args = [number(config.interval, colored), number(config.slow_percent, colored), number(config.slow_duration, colored)]
        "taurus":
            args = [number(config.speed_step, colored), number(config.speed_cap, colored), number(config.invincible_duration, colored), icon(Keys.stat_speed_hash)]
        "aries":
            args = [number(config.speed_threshold, colored), number(config.charges, colored), icon(Keys.stat_speed_hash)]
        "cancer":
            args = [number(100 - config.damage_taken_percent, colored)]
        "leo":
            args = []
        "virgo":
            args = [number(config.iframe_multiplier, colored)]
        "libra":
            args = [number(5, colored), number(5, colored), number(10, colored), icon(Keys.stat_percent_damage_hash), icon(Keys.stat_attack_speed_hash), icon(Keys.stat_range_hash)]
        "d6":
            args = [number(config.chance * 100.0, colored)]
        "mr_bomb", "bomb_bogo":
            args = [number(config.amount, colored)]
        "holy_wafer":
            args = [number(100 - config.damage_taken_percent, colored)]
        "moms_knife":
            args = [number(config.attacks, colored), number(config.damage_multiplier, colored), number(config.cooldown, colored)]
        "rock_bottom":
            args = []
        "light_crown":
            args = [number(config.full_damage, colored), number(config.damaged_damage, colored), icon(Keys.stat_percent_damage_hash)]
        "money_equals_power":
            args = [number(config.gold_step, colored), number(config.damage, colored), icon(Keys.stat_percent_damage_hash)]
        "soy_milk":
            args = [number(effect.value, colored), icon(Keys.stat_attack_speed_hash), number(config.damage_factor, colored)]
        "polyphemus":
            args = [number(effect.value, colored), icon(Keys.stat_percent_damage_hash), number(config.attack_speed_factor, colored), icon(Keys.stat_attack_speed_hash)]
        "double_vision":
            args = [number(config.projectiles, colored)]
        "eight_inch_nails":
            args = [number(config.base_chance * 100.0, colored), icon(Keys.stat_luck_hash), number(config.knockback, colored), number(config.luck_chance * 2000.0, colored)]
        "tough_love":
            args = [number(config.base_chance * 100.0, colored), number(config.damage_multiplier, colored), icon(Keys.stat_luck_hash), number(config.luck_chance * 1000.0, colored)]
        "ipecac":
            var explosion_scaling = [[Keys.stat_ranged_damage_hash, 0.5 * config.damage_factor], [Keys.stat_melee_damage_hash, 0.5 * config.damage_factor], [Keys.stat_elemental_damage_hash, config.damage_factor]]
            var burn_scaling = [[Keys.stat_elemental_damage_hash, config.burn_coefficient]]
            args = [number(config.attacks, colored), scaling_text(explosion_scaling, colored), scaling_text(burn_scaling, colored), number(config.duration, colored)]
        "brother_bobby", "sister_maggy", "ghost_baby", "seraphim", "little_steven", "demon_baby":
            var kind = load("res://mods-unpacked/Local-Isaac/baby_rules.gd").IDS.find(name)
            var stats = pet_attack(kind, 3, p, factor)
            args = [formula(stats, colored), number(stats.piercing, colored), number(abs(stats.speed_percent_modifier), colored)]
        "rainbow_baby":
            for mode in range(5):
                args.append(formula(pet_attack(3, mode, p, factor), colored))
            args.append(pet_burn(config.burn_coefficient, p, colored))
            args.append(number(config.duration, colored))
        "bobs_brain":
            var raw = WeaponStats.new()
            raw.damage = config.damage
            raw.scaling_stats = [[Keys.stat_elemental_damage_hash, config.scaling]]
            var init = WeaponServiceInitStatsArgs.new()
            init.effects = [load("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")]
            var stats = WeaponService.init_base_stats(raw, p, init, false, false, true)
            args = [formula(stats, colored), pet_burn(config.burn_coefficient, p, colored), number(5, colored), number(config.respawn, colored)]
        "incubus":
            args = [number((1.0 + factor) * 100.0, colored)]
        "succubus":
            var multiplier = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd").multiplier(p)
            args = [number(config.interval, colored), number(int(round(config.damage * multiplier)), colored), icon(Keys.stat_percent_damage_hash)]
        "best_friends_forever":
            args = [number(config.damage_multiplier, colored), number(config.aura_multiplier, colored), number(1.0 + config.orbit_speed_percent / 100.0, colored)]
        "max_hp":
            args = [negative_number(effect.value, colored)]
        _:
            args = [number(effect.value, colored)]
    var result = Text.text(key, args)
    if name == "gemini":
        var game = Utils.get_scene_node()
        if game is Main and game.get("isaac_gemini") != null:
            var extra = game.isaac_gemini.description(p)
            if extra != "":
                result += "\n" + extra
    if name == "dressed_boy":
        var allocation = load("res://mods-unpacked/Local-Isaac/new_items_019.gd").allocation(effect, p)
        if not allocation.empty():
            result += "\n" + load("res://mods-unpacked/Local-Isaac/new_items_019.gd").allocation_text(allocation, p)
    return result
