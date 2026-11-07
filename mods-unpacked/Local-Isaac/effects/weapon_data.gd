extends "res://items/global/weapon_data.gd"

export(int) var isaac_coin_progress = 0
export(int) var isaac_sword_scaling_version = 1
export(int) var isaac_pickaxe_balance_version = 1
export(int) var isaac_catalog031_version = 1
export(int) var isaac_balance032_version = 1
export(int) var isaac_balance034_version = 1
export(int) var isaac_balance038_version = 1
export(int) var isaac_balance039_version = 1
export(int) var isaac_balance040_version = 1
export(int) var isaac_catalog041_version = 1
export(int) var isaac_balance0411_version = 1

func serialize() -> Dictionary:
    var result = .serialize()
    result.isaac_coin_progress = isaac_coin_progress
    result.isaac_sword_scaling_version = isaac_sword_scaling_version
    result.isaac_pickaxe_balance_version = isaac_pickaxe_balance_version
    result.isaac_catalog031_version = isaac_catalog031_version
    result.isaac_balance032_version = isaac_balance032_version
    result.isaac_balance034_version = isaac_balance034_version
    result.isaac_balance038_version = isaac_balance038_version
    result.isaac_balance039_version = isaac_balance039_version
    result.isaac_balance040_version = isaac_balance040_version
    result.isaac_catalog041_version = isaac_catalog041_version
    result.isaac_balance0411_version = isaac_balance0411_version
    return result

func deserialize_and_merge(saved: Dictionary) -> void:
    var label = tracking_text
    .deserialize_and_merge(saved)
    isaac_coin_progress = max(0, int(saved.get("isaac_coin_progress", 0)))
    if label != "" and label != "[EMPTY]":
        tracking_text = label
    normalize_coin_growth()
    if weapon_id == "weapon_local_isaac_spirit_sword" and int(saved.get("isaac_sword_scaling_version", 0)) < 1:
        # Native Curse also scales this coefficient. Rebase the old 50% value
        # proportionally, preserving its actual saved Curse roll, exactly once.
        for row in stats.scaling_stats:
            var stat_hash = Keys.generate_hash(row[0]) if typeof(row[0]) == TYPE_STRING else int(row[0])
            if stat_hash == Keys.stat_max_hp_hash:
                row[1] *= [0.2, 0.3, 0.4, 0.5][clamp(tier, 0, 3)] / 0.5
    isaac_sword_scaling_version = 1
    if weapon_id == "weapon_local_isaac_broken_pickaxe" and int(saved.get("isaac_pickaxe_balance_version", 0)) < 1:
        var template = ItemService.get_element_safe(ItemService.weapons, my_id)
        if template != null:
            var factor = load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").stats_factor(stats, is_cursed)
            stats.damage = int(ceil(template.stats.damage * factor))
            stats.scaling_stats = template.stats.scaling_stats.duplicate(true)
            for row in stats.scaling_stats:
                row[1] *= factor
            stats.crit_chance = template.stats.crit_chance
            stats.cooldown = template.stats.cooldown
            stats.recoil_duration = template.stats.recoil_duration
            stats.max_range = template.stats.max_range
            value = template.value
    isaac_pickaxe_balance_version = 1
    normalize_pickaxe_growth()
    if int(saved.get("isaac_catalog031_version", 0)) < 1:
        if weapon_id == "weapon_local_isaac_broken_pickaxe":
            var current = ItemService.get_element_safe(ItemService.weapons, my_id)
            if current != null:
                sets = current.sets.duplicate()
        elif weapon_id == "weapon_local_isaac_boomerang":
            # Match the native Curse increase from a new base piercing of one,
            # preserving any larger saved piercing bonus rather than reducing it.
            stats.piercing = max(stats.piercing, 2 if is_cursed else 1)
    isaac_catalog031_version = 1
    if int(saved.get("isaac_balance032_version", 0)) < 1:
        normalize_balance032()
    isaac_balance032_version = 1
    if weapon_id == "weapon_local_isaac_pointed_rib":
        stats.alternate_attack_type = true
    if weapon_id == "weapon_local_isaac_data_hack" and int(saved.get("isaac_balance034_version", 0)) < 1:
        var data_hack_template = ItemService.get_element_safe(ItemService.weapons, my_id)
        if data_hack_template != null:
            # The pose comes from the current scene, never the save. Only the
            # reduced native range and its complete .88s action/cooldown pair
            # change; keep actual Curse rolls, damage, effects and rewards.
            stats.max_range = data_hack_template.stats.max_range
            stats.cooldown = data_hack_template.stats.cooldown
            stats.recoil_duration = data_hack_template.stats.recoil_duration
    isaac_balance034_version = 1
    # Update only the effects restored from the old save before 0.38's helper
    # can append a missing growth effect from the already-current template.
    normalize_balance039(int(saved.get("isaac_balance039_version", 0)) < 1)
    isaac_balance039_version = 1
    # Migrate saved effects before 0.38 can append an already-current missing
    # growth effect. Older Rib stats are rebuilt from the current template by
    # 0.38 below, so only its already-migrated saves need the extra .8 -> .6.
    if int(saved.get("isaac_balance040_version", 0)) < 1:
        normalize_balance040(int(saved.get("isaac_balance038_version", 0)) >= 1)
    isaac_balance040_version = 1
    normalize_rib038(int(saved.get("isaac_balance038_version", 0)) < 1)
    isaac_balance038_version = 1
    var was_placeholder041 = int(saved.get("isaac_catalog041_version", 0)) < 1 and saved.stats.type == "base"
    if int(saved.get("isaac_catalog041_version", 0)) < 1:
        normalize_catalog041(was_placeholder041)
    isaac_catalog041_version = 1
    if int(saved.get("isaac_balance0411_version", 0)) < 1:
        normalize_balance0411(was_placeholder041)
    isaac_balance0411_version = 1
    normalize_death_set0411()

func normalize_balance0411(from_current_template: bool) -> void:
    if weapon_id != "weapon_local_isaac_deaths_touch" and weapon_id != "weapon_local_isaac_spear_of_destiny":
        return
    var current = ItemService.get_element_safe(ItemService.weapons, my_id)
    if current == null:
        return
    if weapon_id == "weapon_local_isaac_spear_of_destiny":
        # Display-only change: keep every saved melee stat and effect.
        icon = current.icon
        return
    # Stats have their own native Curse roll; the item's curse_factor may be
    # a stronger fear-effect roll. Recover the stat roll from its ranged row.
    # Old placeholders were just rebuilt from the current 100% template above.
    var previous_scaling = 0.8 if tier == 2 and not from_current_template else 1.0
    var ranged = WeaponService.find_scaling_stat(Keys.stat_ranged_damage_hash, stats.scaling_stats)
    var factor = stepify(max(1.0, float(ranged[1]) / previous_scaling), 0.000001) if is_cursed and ranged != null else 1.0
    if is_cursed and ranged == null:
        factor = 1.0 + max(0.0, curse_factor)
    stats.damage = int(ceil(current.stats.damage * factor))
    stats.scaling_stats = current.stats.scaling_stats.duplicate(true)
    for row in stats.scaling_stats:
        row[1] *= factor
    stats.crit_chance = current.stats.crit_chance
    stats.crit_damage = stepify(current.stats.crit_damage * (1.0 + (factor - 1.0) / 5.0), 0.1) if is_cursed else current.stats.crit_damage
    stats.cooldown = current.stats.cooldown
    stats.recoil_duration = current.stats.recoil_duration
    stats.max_range = current.stats.max_range
    stats.bounce = int(min(current.stats.bounce + 1, ceil(current.stats.bounce * (1.0 + (factor - 1.0) / 5.0)))) if is_cursed else current.stats.bounce
    stats.piercing = int(min(current.stats.piercing + 1, ceil(current.stats.piercing * (1.0 + (factor - 1.0) / 5.0)))) if is_cursed else current.stats.piercing
    stats.piercing_dmg_reduction = current.stats.piercing_dmg_reduction
    stats.bounce_dmg_reduction = current.stats.bounce_dmg_reduction

func normalize_death_set0411() -> void:
    if weapon_id != "weapon_local_isaac_deaths_touch":
        return
    for existing in sets:
        if existing.my_id == "set_local_isaac_death":
            return
    # Native deserialization replaces template sets with the saved list. Only
    # append our missing family; preserve saved third-party set membership.
    var death_set = ItemService.get_element_safe(ItemService.sets, "set_local_isaac_death")
    if death_set != null:
        sets.append(death_set.duplicate())

func normalize_catalog041(was_placeholder: bool) -> void:
    if not was_placeholder or (weapon_id != "weapon_local_isaac_spear_of_destiny" and weapon_id != "weapon_local_isaac_deaths_touch"):
        return
    var current = ItemService.get_element_safe(ItemService.weapons, my_id)
    if current == null:
        return
    # 0.32-0.40's unobtainable purple entries had generic zero-damage stats.
    # Keep their purple IDs/tier and saved counters; never turn them into blue.
    type = current.type
    value = current.value
    sets = current.sets.duplicate()
    is_lockable = current.is_lockable
    stats = current.stats.duplicate(true)
    if is_cursed:
        # Old placeholders had no effects, so the saved item factor is the
        # actual original stat roll. Reuse it without sampling a new Curse.
        var factor = 1.0 + max(0.0, curse_factor)
        stats.damage = int(ceil(stats.damage * factor))
        for row in stats.scaling_stats:
            row[1] *= factor
        stats.crit_damage = stepify(stats.crit_damage * (1.0 + (factor - 1.0) / 5.0), 0.1)
        if stats is RangedWeaponStats:
            stats.piercing = int(min(stats.piercing + 1, ceil(stats.piercing * (1.0 + (factor - 1.0) / 5.0))))
    for effect in current.effects:
        var present = false
        for existing in effects:
            if existing.key == effect.key:
                present = true
                break
        if not present:
            var added = effect.duplicate()
            if is_cursed:
                added.curse_factor = max(0.0, curse_factor)
                added.value = int(ceil(added.value * (1.0 + added.curse_factor)))
            effects.append(added)

func normalize_balance040(rebase_rib_stats: bool) -> void:
    if weapon_id != "weapon_local_isaac_pointed_rib" and weapon_id != "weapon_local_isaac_wooden_nickel":
        return
    var current_tier = clamp(tier, 0, 3)
    if weapon_id == "weapon_local_isaac_pointed_rib" and rebase_rib_stats:
        for row in stats.scaling_stats:
            var stat_hash = Keys.generate_hash(row[0]) if typeof(row[0]) == TYPE_STRING else int(row[0])
            if stat_hash == Keys.stat_melee_damage_hash:
                # Keep the native independently sampled stat Curse strength.
                row[1] *= 0.6 / 0.8
    for effect in effects:
        if weapon_id == "weapon_local_isaac_pointed_rib" and effect.key == "effect_local_isaac_rib_growth":
            var previous = [12, 11, 10, 8][current_tier]
            var updated = [10, 9, 8, 6][current_tier]
            # Rebase the effective saved value, without sampling Curse again
            # or substituting the weapon's strongest Curse factor.
            effect.value = int(max(1.0, floor(float(effect.value) * updated / previous)))
            effect.effect_sign = Effect.Sign.NEGATIVE
        elif weapon_id == "weapon_local_isaac_wooden_nickel" and effect.key == "effect_local_isaac_nickel_coin":
            var previous = [20, 30, 40, 50][current_tier]
            var updated = [10, 20, 30, 40][current_tier]
            effect.value = int(ceil(float(effect.value) * updated / previous))

func normalize_balance039(rebase: bool) -> void:
    if weapon_id != "weapon_local_isaac_pointed_rib" and weapon_id != "weapon_local_isaac_wooden_nickel":
        return
    var current_tier = clamp(tier, 0, 3)
    var has_clear = false
    for index in range(effects.size() - 1, -1, -1):
        var effect = effects[index]
        if weapon_id == "weapon_local_isaac_pointed_rib":
            if effect.key == "effect_local_isaac_rib_collision" or effect.key == "effect_local_isaac_rib_size":
                effects.remove(index)
            elif effect.key == "effect_local_isaac_rib_clear":
                has_clear = true
            elif rebase and effect.key == "effect_local_isaac_rib_growth":
                var previous = [18, 16, 14, 12][current_tier]
                var updated = [12, 11, 10, 8][current_tier]
                # Preserve the old effect's effective Curse reduction, rather
                # than rerolling or substituting the weapon's maximum roll.
                effect.value = max(1, int(effect.value * updated / previous))
                effect.effect_sign = Effect.Sign.NEGATIVE
        elif rebase and effect.key == "effect_local_isaac_nickel_coin":
            var previous = [5, 10, 15, 20][current_tier]
            var updated = [20, 30, 40, 50][current_tier]
            effect.value = int(ceil(float(effect.value) * updated / previous))
    if weapon_id != "weapon_local_isaac_pointed_rib" or has_clear:
        return
    var current = ItemService.get_element_safe(ItemService.weapons, my_id)
    if current == null:
        return
    for effect in current.effects:
        if effect.key == "effect_local_isaac_rib_clear":
            var added = effect.duplicate()
            if is_cursed:
                added.curse_factor = max(0.0, curse_factor)
                added.value = int(ceil(added.value * (1.0 + added.curse_factor)))
            effects.append(added)
            return

func normalize_rib038(rebase: bool) -> void:
    if weapon_id != "weapon_local_isaac_pointed_rib":
        return
    var current = ItemService.get_element_safe(ItemService.weapons, my_id)
    if current == null:
        return
    if rebase:
        # 0.37 had 100% melee scaling and no HP row. Preserve that stat roll,
        # which native Curse samples independently from its individual effects.
        var melee = WeaponService.find_scaling_stat(Keys.stat_melee_damage_hash, stats.scaling_stats)
        var factor = stepify(max(1.0, float(melee[1])), 0.000001) if is_cursed and melee != null else 1.0
        if is_cursed and melee == null:
            factor = 1.0 + max(0.0, curse_factor)
        stats.damage = int(ceil(current.stats.damage * factor))
        stats.scaling_stats = current.stats.scaling_stats.duplicate(true)
        for row in stats.scaling_stats:
            row[1] *= factor
        stats.crit_chance = current.stats.crit_chance
        stats.crit_damage = stepify(current.stats.crit_damage * (1.0 + (factor - 1.0) / 5.0), 0.1) if is_cursed else current.stats.crit_damage
        stats.cooldown = current.stats.cooldown
        stats.recoil_duration = current.stats.recoil_duration
        stats.max_range = current.stats.max_range
        stats.knockback = current.stats.knockback
        sets = current.sets.duplicate()
        value = current.value
    for effect in effects:
        if effect.key == "effect_local_isaac_rib_growth":
            # A valid saved Curse threshold has its own roll; never replace it
            # using the item's maximum curse_factor or grant a reward on load.
            effect.value = max(1, int(effect.value))
            effect.effect_sign = Effect.Sign.NEGATIVE
            return
    for effect in current.effects:
        if effect.key == "effect_local_isaac_rib_growth":
            var added = effect.duplicate()
            if is_cursed:
                added.curse_factor = max(0.0, curse_factor)
                added.value = int(max(1.0, floor(added.value / (1.0 + added.curse_factor))))
            effects.append(added)
            return

func normalize_balance032() -> void:
    if weapon_id != "weapon_local_isaac_boomerang" and weapon_id != "weapon_local_isaac_spirit_sword":
        return
    var current = ItemService.get_element_safe(ItemService.weapons, my_id)
    if current == null:
        return
    sets = current.sets.duplicate()
    if weapon_id != "weapon_local_isaac_boomerang":
        return
    var ranged = WeaponService.find_scaling_stat(Keys.stat_ranged_damage_hash, stats.scaling_stats)
    # Native saved coefficients originate in integer percentages. Remove float
    # serialization noise before ceil/half-step critical rounding (e.g. 1.2/.8).
    var factor = stepify(max(1.0, float(ranged[1]) / 0.8), 0.000001) if is_cursed and ranged != null else 1.0
    stats.damage = int(ceil(current.stats.damage * factor))
    stats.scaling_stats = current.stats.scaling_stats.duplicate(true)
    for row in stats.scaling_stats:
        row[1] *= factor
    stats.crit_chance = current.stats.crit_chance
    stats.crit_damage = stepify(current.stats.crit_damage * (1.0 + (factor - 1.0) / 5.0), 0.1) if is_cursed else current.stats.crit_damage
    stats.cooldown = current.stats.cooldown
    stats.recoil_duration = current.stats.recoil_duration
    stats.max_range = current.stats.max_range
    stats.knockback = 0
    stats.bounce = int(min(current.stats.bounce + 1, ceil(current.stats.bounce * (1.0 + (factor - 1.0) / 5.0)))) if is_cursed else current.stats.bounce
    stats.piercing = int(min(current.stats.piercing + 1, ceil(current.stats.piercing * (1.0 + (factor - 1.0) / 5.0)))) if is_cursed else current.stats.piercing
    stats.piercing_dmg_reduction = current.stats.piercing_dmg_reduction
    stats.bounce_dmg_reduction = current.stats.bounce_dmg_reduction
    value = current.value
    var has_petrify = false
    for effect in effects:
        has_petrify = has_petrify or effect.key == "effect_local_isaac_boomerang_petrify"
    if not has_petrify:
        for effect in current.effects:
            if effect.key == "effect_local_isaac_boomerang_petrify":
                var added = effect.duplicate()
                if is_cursed:
                    added.value = int(ceil(added.value * (1.0 + max(0.0, curse_factor))))
                effects.append(added)

func normalize_pickaxe_growth() -> void:
    if weapon_id != "weapon_local_isaac_broken_pickaxe":
        return
    # Add missing features once, keeping saved stats and counters intact.
    var template = ItemService.get_element_safe(ItemService.weapons, my_id)
    if template == null:
        return
    for effect in template.effects:
        var present = false
        for existing in effects:
            if existing.key == effect.key:
                present = true
                break
        if present:
            continue
        var added = effect.duplicate()
        if is_cursed:
            added.value = int(ceil(added.value * (1.0 + max(0.0, curse_factor))))
        effects.append(added)
    load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd").stamp(self)

func normalize_coin_growth() -> void:
    if weapon_id != "weapon_local_isaac_wooden_nickel":
        return
    for effect in effects:
        if effect.key != "effect_local_isaac_nickel_growth":
            continue
        if effect.effect_sign == Effect.Sign.NEGATIVE:
            return
        # Older versions wrongly marked a cost as beneficial. Saved weapon
        # Curse coefficients are native fields; repair without rerolling or
        # touching collected materials, remainder, stats or permanent rewards.
        if is_cursed:
            var base = [25, 20, 15, 10][clamp(tier, 0, 3)]
            var factor = max(0.0, max(float(effect.curse_factor), float(curse_factor)))
            if factor <= 0.0 and effect.value > base:
                factor = float(effect.value) / base - 1.0
            effect.value = int(max(1.0, floor(base / (1.0 + factor))))
        effect.effect_sign = Effect.Sign.NEGATIVE
