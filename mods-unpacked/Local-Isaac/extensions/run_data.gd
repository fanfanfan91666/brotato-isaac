extends "res://singletons/run_data.gd"

const ISAAC_KEEPER_ATTACK_SPEED_META = "local_isaac_keeper_attack_speed_baseline"

var isaac_resetting_run = false
var isaac_libra_after_reset = {}
var isaac_effect_defaults = {}
var isaac_effect_schema_key = 0
var isaac_bomb_stat_key = 0
var isaac_pageant_rows_key = 0
var isaac_pageant_revision_key = 0
var isaac_pageant_hydrated = {}
var isaac_devil_chance_stat_key = 0
var isaac_angel_chance_stat_key = 0
var isaac_mutation_sources = {}

func get_state() -> Dictionary:
    var state = .get_state()
    var rows = []
    # Native PlayerRunData.duplicate() shares WeaponData resources. Store an
    # independent numeric snapshot for retry-wave rollback, not on stat reads.
    for player in players_data:
        var progress = []
        for weapon in player.weapons:
            progress.append(int(weapon.isaac_coin_progress) if weapon.weapon_id == "weapon_local_isaac_wooden_nickel" else 0)
        rows.append(progress)
    state.isaac_coin_progress = rows
    state.isaac_special_room_rows = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").get_state()
    state.isaac_room_chance_rows = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").get_chance_state()
    state.isaac_resurrection_rows_0412 = load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").get_state()
    return state

func resume_from_state(state: Dictionary) -> void:
    .resume_from_state(state)
    reset_run_caches()
    load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").restore_state(state.get("isaac_special_room_rows", []))
    load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").restore_chance_state(state.get("isaac_room_chance_rows", []))
    load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").restore_state(state.get("isaac_resurrection_rows_0412", []))
    var rows = state.get("isaac_coin_progress", [])
    for p in min(rows.size(), players_data.size()):
        for slot in min(rows[p].size(), players_data[p].weapons.size()):
            var weapon = players_data[p].weapons[slot]
            if weapon.weapon_id == "weapon_local_isaac_wooden_nickel":
                weapon.isaac_coin_progress = max(0, int(rows[p][slot]))
    # Older run snapshots lack newly registered counters. Merge once on load;
    # never scan/init them on the high-frequency attribute or damage paths.
    for counters in tracked_item_effects:
        for key in init_tracked_items:
            if not counters.has(key):
                var initial = init_tracked_items[key]
                counters[key] = initial.duplicate(true) if initial is Array or initial is Dictionary else initial
    # Saved active_set_effects retain the exact old applied Effect values,
    # including Anger's former enemy-count bonus. Native update_sets un-applies
    # those saved effects before applying today's set resources, so load/retry
    # never leaves the old enemy count or subtracts today's Damage/Crit bonus.
    # Rebuild only here, never on attribute reads.
    # Repeating this on resume also handles shallow-shared WeaponData snapshots.
    for p in players_data.size():
        isaac_cache_keeper_attack_speed(p)
        var character = players_data[p].current_character
        if character != null and character.my_id == "character_local_forgotten":
            # Restore the native restriction without deleting already-owned
            # ranged weapons from older runs.
            players_data[p].effects[Keys.no_ranged_weapons_hash] = max(1, int(players_data[p].effects.get(Keys.no_ranged_weapons_hash, 0)))
        for weapon in players_data[p].weapons:
            if weapon.weapon_id in ["weapon_local_isaac_broken_pickaxe", "weapon_local_isaac_boomerang", "weapon_local_isaac_spirit_sword", "weapon_local_isaac_pointed_rib", "weapon_local_isaac_sacrificial_dagger", "weapon_local_isaac_spear_of_destiny", "weapon_local_isaac_deaths_touch"]:
                update_sets(p)
                break

func isaac_prepare_effect_keys() -> void:
    if isaac_effect_schema_key != 0:
        return
    for row in [["stat_local_isaac_bombs", 0], ["local_isaac_rocks", 0], ["local_isaac_knife_progress", 0], ["local_isaac_rock_bottom_peaks", {}], ["local_isaac_ipecac_weapon_progress", []], ["local_isaac_pageant_rows", []], ["local_isaac_pageant_selected", []], ["local_isaac_pageant_revision", 0]]:
        isaac_effect_defaults[Keys.generate_hash(row[0])] = row[1]
    isaac_effect_schema_key = Keys.generate_hash("local_isaac_effect_schema")
    isaac_bomb_stat_key = Keys.generate_hash("stat_local_isaac_bombs")
    isaac_pageant_rows_key = Keys.generate_hash("local_isaac_pageant_rows")
    isaac_pageant_revision_key = Keys.generate_hash("local_isaac_pageant_revision")

func reset(restart: bool = false) -> void:
    load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").reset_state()
    load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").reset_state()
    isaac_mutation_sources.clear()
    isaac_pageant_hydrated.clear()
    if restart:
        for data in players_data:
            if data.selected_item != null and data.selected_item.my_id == "item_local_isaac_dressed_boy":
                var saved = data.effects.get(Keys.generate_hash("local_isaac_pageant_selected"), [])
                if not saved.empty():
                    data.selected_item.isaac_random_points = saved.duplicate()
    isaac_resetting_run = true
    isaac_libra_after_reset.clear()
    .reset(restart)
    isaac_resetting_run = false
    for p in players_data.size():
        isaac_cache_keeper_attack_speed(p)
    for p in isaac_libra_after_reset:
        if p < get_player_count() and get_nb_item(Keys.generate_hash("item_local_isaac_libra"), p) > 0:
            load("res://mods-unpacked/Local-Isaac/zodiac_balance.gd").apply(p)
    isaac_libra_after_reset.clear()

func add_character(character: CharacterData, player_index: int) -> void:
    .add_character(character, player_index)
    isaac_cache_keeper_attack_speed(player_index)

func isaac_cache_keeper_attack_speed(player_index: int) -> void:
    var owner = players_data[player_index]
    var correction = 0.0
    if owner.current_character != null and owner.current_character.my_id == "character_local_keeper":
        # On save restoration current_character points at today's template,
        # while items owns the actual saved character effects. Only a saved
        # modifier grants the correction; older Keeper runs get neither one.
        for item in owner.items:
            if item.my_id != "character_local_keeper":
                continue
            for effect in item.effects:
                if effect is StatGainsModificationEffect and effect.custom_key == "local_isaac_keeper_attack_speed_gain" and "stat_attack_speed" in effect.stats_modified:
                    correction += float(effect.value)
    owner.set_meta(ISAAC_KEEPER_ATTACK_SPEED_META, correction)
    Utils.reset_stat_cache(player_index)

func get_stat(stat_hash: int, player_index: int) -> float:
    # These derived probabilities live in numeric run-state rows, outside the
    # native/private effects dictionaries and their serialized schemas.
    if isaac_devil_chance_stat_key == 0:
        isaac_devil_chance_stat_key = Keys.generate_hash("stat_local_isaac_devil_room_chance")
        isaac_angel_chance_stat_key = Keys.generate_hash("stat_local_isaac_angel_room_chance")
    if stat_hash == isaac_devil_chance_stat_key or stat_hash == isaac_angel_chance_stat_key:
        return load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").chance_stat(stat_hash, player_index)
    var result = .get_stat(stat_hash, player_index)
    if stat_hash != Keys.stat_attack_speed_hash or player_index == DUMMY_PLAYER_INDEX:
        return result
    var owner = players_data[player_index]
    if owner.current_character == null or owner.current_character.my_id != "character_local_keeper":
        return result
    if not owner.has_meta(ISAAC_KEEPER_ATTACK_SPEED_META):
        # Native PlayerRunData.duplicate() omits metadata. Hydrate that copy
        # once; the frequent getter thereafter reads only the cached scalar.
        isaac_cache_keeper_attack_speed(player_index)
    # Native gain_ also scales the initial -100. Its own -.3 would raise that
    # baseline by 30, so offset just that fixed change. Permanent, temporary
    # and linked gains retain native .7 scaling and native modifier stacking.
    return result + float(owner.get_meta(ISAAC_KEEPER_ATTACK_SPEED_META))

func on_wave_start(timer: WaveTimer) -> void:
    load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").begin_wave()
    .on_wave_start(timer)

func on_wave_end() -> void:
    # Resolve before native resets wave_in_progress and saves shop state.
    load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").complete_wave()
    .on_wave_end()

func get_player_effects(player_index: int) -> Dictionary:
    var effects = .get_player_effects(player_index)
    isaac_prepare_effect_keys()
    if effects.get(isaac_effect_schema_key, 0) == 20 and effects.has(isaac_bomb_stat_key):
        return effects
    # Initialise once per restored effect dictionary, not on every stat read.
    # A new schema revision must be used when adding future private defaults.
    for key in isaac_effect_defaults:
        if not effects.has(key):
            var value = isaac_effect_defaults[key]
            effects[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    effects[isaac_effect_schema_key] = 20
    return effects

func get_player_items(player_index: int) -> Array:
    var result = .get_player_items(player_index)
    if player_index == DUMMY_PLAYER_INDEX:
        return result
    isaac_prepare_effect_keys()
    var data_owner = players_data[player_index]
    var rows = data_owner.effects.get(isaac_pageant_rows_key, [])
    if rows.empty():
        return result
    var revision = int(data_owner.effects.get(isaac_pageant_revision_key, 0))
    var cached = isaac_pageant_hydrated.get(player_index, [])
    if cached.size() == 3 and cached[0] == data_owner and cached[1] == revision and cached[2] == result.size():
        return result
    var ordinal = 0
    for data in result:
        if data.my_id != "item_local_isaac_dressed_boy":
            continue
        if ordinal < rows.size():
            data.isaac_random_points = rows[ordinal].duplicate()
            for i in data.isaac_random_points.size():
                data.isaac_random_points[i] = int(data.isaac_random_points[i])
        ordinal += 1
    isaac_pageant_hydrated[player_index] = [data_owner, revision, result.size()]
    return result

func add_item(item: ItemData, player_index: int, is_selection: bool = false) -> void:
    var mutation_source = isaac_mutation_sources.get(player_index)
    var same_item_mutation = mutation_source != null and mutation_source.my_id == item.my_id
    if mutation_source != null:
        isaac_mutation_sources.erase(player_index)
        if not same_item_mutation:
            isaac_finish_item_removal(mutation_source, player_index)
    if item.my_id == "item_local_isaac_dressed_boy" and not same_item_mutation:
        item = load("res://mods-unpacked/Local-Isaac/new_items_019.gd").prepare_random(item, isaac_resetting_run and is_selection)
    .add_item(item, player_index, is_selection)
    if item.my_id == "item_local_isaac_dressed_boy":
        get_player_effects(player_index)[Keys.generate_hash("local_isaac_pageant_rows")].append(item.isaac_random_points.duplicate())
        get_player_effects(player_index)[isaac_pageant_revision_key] += 1
    if same_item_mutation:
        return
    load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").item_added(item, player_index)
    if item.my_id == "item_local_isaac_dressed_boy":
        if is_selection:
            get_player_effects(player_index)[Keys.generate_hash("local_isaac_pageant_selected")] = item.isaac_random_points.duplicate()
        load("res://mods-unpacked/Local-Isaac/new_items_019.gd").grant_random(item, player_index)
    if item.my_id == "item_local_isaac_libra":
        if isaac_resetting_run:
            isaac_libra_after_reset[player_index] = true
        else:
            load("res://mods-unpacked/Local-Isaac/zodiac_balance.gd").apply(player_index)
    if item.my_id == "item_local_isaac_mr_bomb":
        var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
        var bombs = int(curses.params("mr_bomb", curses.item_factor(item)).amount)
        preload("res://mods-unpacked/Local-Isaac/bomb_rules.gd").change_count(player_index, bombs)
        if bombs > 0:
            RunData.add_tracked_value(player_index, item.my_id_hash, bombs)

func mutate_random_item(player_index: int):
    var result = .mutate_random_item(player_index)
    var mutation_source = isaac_mutation_sources.get(player_index)
    if mutation_source != null:
        isaac_mutation_sources.erase(player_index)
        isaac_finish_item_removal(mutation_source, player_index)
    return result

func remove_item(item: ItemData, player_index: int, by_id: bool = false, apply_replacement: bool = true) -> void:
    if item.my_id == "item_local_isaac_dressed_boy":
        var outfits = []
        for data in get_player_items(player_index):
            if data.my_id == item.my_id:
                outfits.append(data)
        var ordinal = 0 if by_id and not outfits.empty() else outfits.find(item)
        if ordinal < 0 and not by_id:
            for index in outfits.size():
                if ItemService.is_same_item(item, outfits[index]):
                    ordinal = index
                    break
        var rows = get_player_effects(player_index)[isaac_pageant_rows_key]
        if ordinal >= 0 and ordinal < rows.size():
            rows.remove(ordinal)
            get_player_effects(player_index)[isaac_pageant_revision_key] += 1
    # Primal Dread removes the source and adds its mutation synchronously. A
    # same-ID replacement keeps acquisition-only bonuses and the spent ledger.
    var mutation = _is_mutating and not apply_replacement and item.my_id.begins_with("item_local_isaac_")
    if mutation:
        isaac_mutation_sources[player_index] = item
    .remove_item(item, player_index, by_id, apply_replacement)
    if not mutation:
        isaac_finish_item_removal(item, player_index, by_id)

func isaac_finish_item_removal(item: ItemData, player_index: int, by_id: bool = false) -> void:
    load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").item_removed(item, player_index, by_id)
    if item.my_id == "item_local_isaac_moms_knife":
        get_player_effects(player_index)[Keys.generate_hash("local_isaac_knife_progress")] = 0
    if item.my_id == "item_local_isaac_rock_bottom" and get_nb_item(item.my_id_hash, player_index) == 0:
        get_player_effects(player_index)[Keys.generate_hash("local_isaac_rock_bottom_peaks")] = {}
        Utils.reset_stat_cache(player_index)
    if item.my_id == "item_local_isaac_ipecac" and get_nb_item(item.my_id_hash, player_index) == 0:
        get_player_effects(player_index)[Keys.generate_hash("local_isaac_ipecac_weapon_progress")] = []

func get_nb_pets(player_index: int) -> int:
    var result = .get_nb_pets(player_index)
    var game = Utils.get_scene_node()
    if game is Main and game.get("isaac_gemini") != null:
        result += game.isaac_gemini.count(player_index)
    return result

func add_weapon(weapon: WeaponData, player_index: int, is_selection: bool = false) -> WeaponData:
    if preload("res://mods-unpacked/Local-Isaac/lilith_rules.gd").is_lilith(player_index):
        return null
    var character = get_player_character(player_index)
    if character != null and character.my_id == "character_local_forgotten" and weapon.type == WeaponType.RANGED:
        return null
    var new_weapon = .add_weapon(weapon, player_index, is_selection)
    if is_selection and new_weapon != null and new_weapon.weapon_id == "weapon_local_isaac_wooden_nickel":
        new_weapon.isaac_coin_progress = 0
        new_weapon.tracked_value = 0
        new_weapon.tracked_value_added_this_wave = 0
    preload("res://mods-unpacked/Local-Isaac/attack_rules.gd").ipecac_rows(player_index)
    return new_weapon

func has_weapon_slot_available(shop_weapon: WeaponData, player_index: int) -> bool:
    if preload("res://mods-unpacked/Local-Isaac/lilith_rules.gd").is_lilith(player_index):
        return false
    var character = get_player_character(player_index)
    if character != null and character.my_id == "character_local_forgotten" and shop_weapon.type == WeaponType.RANGED:
        return false
    return .has_weapon_slot_available(shop_weapon, player_index)

func get_free_weapon_slots(player_index: int) -> int:
    if preload("res://mods-unpacked/Local-Isaac/lilith_rules.gd").is_lilith(player_index):
        return 0
    return .get_free_weapon_slots(player_index)

func player_has_weapon_slots(player_index: int) -> bool:
    if preload("res://mods-unpacked/Local-Isaac/lilith_rules.gd").is_lilith(player_index):
        return false
    return .player_has_weapon_slots(player_index)

func remove_weapon_by_index(index: int, player_index: int) -> int:
    var rows = preload("res://mods-unpacked/Local-Isaac/attack_rules.gd").ipecac_rows(player_index)
    if index >= 0 and index < rows.size():
        rows.remove(index)
    return .remove_weapon_by_index(index, player_index)

func remove_weapon(weapon: WeaponData, player_index: int) -> int:
    var owned = get_player_weapons(player_index)
    var rows = preload("res://mods-unpacked/Local-Isaac/attack_rules.gd").ipecac_rows(player_index)
    for slot in owned.size():
        if ItemService.is_same_weapon(owned[slot], weapon):
            rows.remove(slot)
            break
    return .remove_weapon(weapon, player_index)

func remove_all_weapons(player_index: int) -> void:
    .remove_all_weapons(player_index)
    get_player_effects(player_index)[Keys.generate_hash("local_isaac_ipecac_weapon_progress")] = []

func combine_weapon(weapon_data: WeaponData, other_weapon, player_index: int) -> WeaponData:
    if weapon_data.weapon_id != "weapon_local_isaac_wooden_nickel":
        return .combine_weapon(weapon_data, other_weapon, player_index)
    var previous = get_player_weapons(player_index)
    var result = .combine_weapon(weapon_data, other_weapon, player_index)
    isaac_transfer_coin_progress(previous, result, player_index)
    return result

func meca_upgrade_weapon(weapon_data: WeaponData, upgraded_weapon: WeaponData, player_index: int) -> WeaponData:
    if weapon_data.weapon_id != "weapon_local_isaac_wooden_nickel":
        return .meca_upgrade_weapon(weapon_data, upgraded_weapon, player_index)
    var previous = get_player_weapons(player_index)
    var result = .meca_upgrade_weapon(weapon_data, upgraded_weapon, player_index)
    isaac_transfer_coin_progress(previous, result, player_index)
    return result

func isaac_transfer_coin_progress(previous: Array, result: WeaponData, player_index: int) -> void:
    if result == null or result.weapon_id != "weapon_local_isaac_wooden_nickel":
        return
    var current = get_player_weapons_ref(player_index)
    var progress = 0
    for old in previous:
        if old.weapon_id == result.weapon_id and not current.has(old):
            progress += old.isaac_coin_progress
    result.isaac_coin_progress = progress
    load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").settle_coin(result, player_index)

func add_gold(value: int, player_index: int) -> void:
    .add_gold(value, player_index)
    isaac_money_stats_changed(player_index)

func remove_gold(value: int, player_index: int) -> void:
    .remove_gold(value, player_index)
    isaac_money_stats_changed(player_index)

func isaac_money_stats_changed(p: int) -> void:
    if get_nb_item(Keys.generate_hash("item_local_isaac_money_equals_power"), p) > 0:
        Utils.reset_stat_cache(p)
        _are_player_stats_dirty[p] = true
