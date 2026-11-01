extends Reference

# Acquisition conversion weights: 5% Damage, 5% Attack Speed and 10 Range.
# This conversion happens once, rather than continuously modifying stats.
const WEIGHTS = [5.0, 5.0, 10.0]

static func stat_keys() -> Array:
    return [Keys.stat_percent_damage_hash, Keys.stat_attack_speed_hash, Keys.stat_range_hash]

static func current(player_index: int) -> Array:
    var result = []
    for stat_key in stat_keys():
        result.append(Utils.get_stat(stat_key, player_index))
    return result

static func targets(values: Array) -> Array:
    if values.size() != WEIGHTS.size():
        return []
    var average = 0.0
    for index in WEIGHTS.size():
        average += float(values[index]) / WEIGHTS[index]
    average /= float(WEIGHTS.size())
    var result = []
    for weight in WEIGHTS:
        # Native stats are integers. Round each axis to the nearest point;
        # retain negative totals instead of creating a free zero-value floor.
        result.append(int(round(average * weight)))
    return result

static func apply(player_index: int) -> Dictionary:
    if player_index < 0 or player_index >= RunData.get_player_count():
        return {}
    var keys_to_balance = stat_keys()
    var snapshot = current(player_index)
    var desired = targets(snapshot)
    var raw_deltas = []
    var unadjustable = []
    for index in keys_to_balance.size():
        var gain = RunData.get_stat_gain(keys_to_balance[index], player_index)
        var difference = float(desired[index]) - float(snapshot[index])
        if abs(gain) < 0.000001:
            # A character/mod can prohibit all gains in a stat. Respect that
            # native restriction rather than dividing by zero or bypassing it.
            raw_deltas.append(0)
            unadjustable.append(keys_to_balance[index])
        else:
            raw_deltas.append(int(round(difference / gain)))
    var effects = RunData.get_player_effects(player_index)
    # Write all permanent deltas atomically, then invalidate once. In
    # particular, do not let Rock Bottom sample intermediate conversions.
    # Temporary/linked sources and the protected-peak dictionary stay intact.
    for index in keys_to_balance.size():
        var stat_key = keys_to_balance[index]
        effects[stat_key] = effects.get(stat_key, 0) + raw_deltas[index]
    RunData._are_player_stats_dirty[player_index] = true
    Utils.reset_stat_cache(player_index)
    return {
        "snapshot": snapshot,
        "targets": desired,
        "raw_deltas": raw_deltas,
        "unadjustable": unadjustable,
        "final": current(player_index)
    }
