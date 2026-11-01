extends Reference

# RunData metadata is session storage. The run-state extension saves only these
# numeric rows, outside Player.effects and its schema/hash conversion.
const META = "isaac_special_room_rows_034"
const VERSION = 2
# Physical card limit; a fresh inventory samples two, three or four entries.
const OFFER_COUNT = 4

static func room_kind(wave: int = -1) -> int:
    var completed_wave = RunData.current_wave if wave < 0 else wave
    if completed_wave <= 0 or completed_wave % 3 != 0:
        return 0
    return 1 if int(completed_wave / 3) % 2 == 1 else 2

static func title_key(wave: int = -1) -> String:
    return "LOCAL_ISAAC_DEVIL_ROOM" if room_kind(wave) == 1 else "LOCAL_ISAAC_ANGEL_ROOM"

static func reset_state() -> void:
    RunData.set_meta(META, [])

static func _numeric_row(raw, length: int) -> bool:
    if not raw is Array or raw.size() != length:
        return false
    for value in raw:
        if not (value is int or value is float):
            return false
    return true

static func _rows() -> Array:
    var rows = RunData.get_meta(META) if RunData.has_meta(META) else []
    if not rows is Array or rows.empty() or not _numeric_row(rows[0], 2) or int(rows[0][1]) != RunData.current_wave:
        rows = [[VERSION, RunData.current_wave]]
        RunData.set_meta(META, rows)
    elif int(rows[0][0]) == 1:
        rows = _restore_rows(rows)
        RunData.set_meta(META, rows)
    elif int(rows[0][0]) != VERSION:
        rows = [[VERSION, RunData.current_wave]]
        RunData.set_meta(META, rows)
    return rows

static func get_state() -> Array:
    return _rows().duplicate(true)

static func restore_state(saved_rows: Array) -> void:
    RunData.set_meta(META, _restore_rows(saved_rows))

static func _restore_rows(saved_rows: Array) -> Array:
    var rows = [[VERSION, RunData.current_wave]]
    if saved_rows.empty() or not _numeric_row(saved_rows[0], 2):
        return rows
    var old_version = int(saved_rows[0][0])
    if not old_version in [1, VERSION] or int(saved_rows[0][1]) != RunData.current_wave:
        return rows
    var seen = {}
    var players = {}
    var sentinels = {}
    var sold_players = {}
    for index in range(1, saved_rows.size()):
        var raw = saved_rows[index]
        if not _numeric_row(raw, 4):
            continue
        var player = int(raw[0])
        var slot = int(raw[1])
        if player < 0 or player >= 4 or slot < -1 or slot >= OFFER_COUNT:
            continue
        var key = player * 8 + slot + 1
        if seen.has(key):
            continue
        seen[key] = true
        players[player] = true
        var row = [player, slot, int(raw[2]), 1 if int(raw[3]) != 0 else 0]
        if slot == -1:
            # v1's sentinel only said "generated". Keep its original four
            # slots, including exhausted pools, without sampling new stock.
            row[2] = OFFER_COUNT if old_version == 1 else int(clamp(row[2], 0, OFFER_COUNT))
            sentinels[player] = row
        elif int(row[3]) != 0:
            sold_players[player] = true
        rows.append(row)
    for player in players:
        if not sentinels.has(player):
            var sentinel = [player, -1, OFFER_COUNT, 0]
            sentinels[player] = sentinel
            rows.append(sentinel)
        # A prior angel sale already granted its item. Seal all other choices;
        # migration never grants, removes or replaces any owned item.
        if room_kind() == 2 and sold_players.has(player):
            sentinels[player][3] = 1
    return rows

static func offer_count_from(value: float) -> int:
    if value < 0.5:
        return 4
    return 2 if value < 0.75 else 3

static func currency_amount(player: int) -> int:
    if room_kind() != 1 or player < 0 or player >= RunData.get_player_count():
        return 0
    if currency_for(player) == "materials":
        return RunData.get_player_gold(player)
    # Native Demon uses uncapped get_stat rather than displayed/effective HP.
    return RunData.get_stat(Keys.stat_max_hp_hash, player) as int

static func currency_for(player: int) -> String:
    if room_kind() != 1:
        return "free"
    if player < 0 or player >= RunData.get_player_count():
        return "hp"
    var character = RunData.get_player_character(player)
    return "materials" if character != null and character.my_id == "character_local_keeper" else "hp"

static func price_for(item: Resource, player: int) -> int:
    if room_kind() != 1 or item == null or player < 0 or player >= RunData.get_player_count():
        return 0
    var value = ItemService.get_value(RunData.current_wave, item.value, player, true, false, item.my_id_hash)
    if currency_for(player) == "materials":
        return value
    return ceil(value / 20.0) as int

static func chosen(player: int) -> bool:
    if room_kind() != 2 or player < 0 or player >= RunData.get_player_count():
        return false
    for row in _rows():
        if row.size() == 4 and int(row[0]) == player and int(row[3]) != 0:
            return true
    return false

static func _item(id: int) -> Resource:
    # Missing/removed mods must not turn an existing slot into a fresh roll.
    for item in ItemService.items:
        if item.my_id_hash == id:
            return item
    return null

static func _eligible(item: Resource, player: int, reserved: Array) -> bool:
    if item == null or not item is ItemData or item is WeaponData or not item.can_be_looted or item.max_nb == 0:
        return false
    if not ProgressData.items_unlocked.has(item.my_id_hash):
        return false
    for banned in RunData.players_data[player].banned_items:
        if banned == item.my_id_hash or banned == item.my_id:
            return false
    var character = RunData.get_player_character(player)
    if RunData.current_wave < RunData.nb_of_waves:
        if character.banned_items.has(item.my_id):
            return false
        for group in character.banned_item_groups:
            if ItemService.item_groups.has(group) and ItemService.item_groups[group].has(item.my_id):
                return false
    elif ItemService.banned_items_for_endless.has(item.my_id) or ItemService.banned_items_for_endless.has(item.my_id_hash):
        return false
    for tag in RunData.get_player_effect(Keys.remove_shop_items_hash, player):
        if Keys.hash_to_string.has(tag) and item.tags.has(Keys.hash_to_string[tag]):
            return false
    if item.max_nb >= 0:
        var count = RunData.get_nb_item(item.my_id_hash, player)
        for other in reserved:
            if other != null and other.my_id_hash == item.my_id_hash:
                count += 1
        if count >= item.max_nb:
            return false
    return true

static func ensure_inventory(player: int, normal_shop_items: Array = []) -> Array:
    if room_kind() == 0 or player < 0 or player >= RunData.get_player_count():
        return []
    var rows = _rows()
    for row in rows:
        if row.size() == 4 and int(row[0]) == player:
            return get_offers(player)
    # The sentinel stores the sampled count and angel choice, including when
    # every legal tier is exhausted. Re-entry and save/resume never resample.
    var offer_count = offer_count_from(randf())
    rows.append([player, -1, offer_count, 0])
    var registered_items = {}
    for item in load("res://mods-unpacked/Local-Isaac/NewContentData.tres").items:
        if item is ItemData and not item is WeaponData:
            registered_items[item.my_id_hash] = true
    var reserved = []
    for offer in normal_shop_items:
        if offer is Array and offer.size() > 0 and offer[0] is ItemData:
            reserved.append(offer[0])
    var selected = []
    for slot in offer_count:
        var tier = ItemService.get_tier_from_wave(RunData.current_wave, player)
        var candidates = []
        # Only this mod's registered items enter the native unlocked item pools
        # and wave/luck tier odds. A depleted tier falls back to a legal tier.
        for candidate_tier in [tier, 0, 1, 2, 3]:
            candidates = []
            for item in ItemService.get_pool(candidate_tier, ItemService.TierData.ITEMS):
                if registered_items.has(item.my_id_hash) and _eligible(item, player, reserved) and not selected.has(item.my_id_hash):
                    candidates.append(item)
            if not candidates.empty():
                break
        if candidates.empty():
            break
        var character = RunData.get_player_character(player)
        var wanted_chance = ItemService.CHANCE_WANTED_ITEM_TAG
        if RunData.get_player_effects(player).has(Keys.stat_boosted_wanted_item_tag_hash) and RunData.get_player_effect_bool(Keys.stat_boosted_wanted_item_tag_hash, player):
            wanted_chance = ItemService.BOOSTED_WANTED_ITEM_TAG
        if Utils.get_chance_success(wanted_chance) and not character.wanted_tags.empty():
            var wanted = []
            for item in candidates:
                for tag in item.tags:
                    if character.wanted_tags.has(tag):
                        wanted.append(item)
                        break
            if not wanted.empty():
                candidates = wanted
        var item = Utils.get_rand_element(candidates)
        # Use the registered base item, without a random cursed variant.
        rows.append([player, slot, item.my_id_hash, 0])
        selected.append(item.my_id_hash)
        reserved.append(item)
    return get_offers(player)

static func get_offers(player: int) -> Array:
    if room_kind() == 0 or player < 0 or player >= RunData.get_player_count():
        return []
    var offers = []
    var kind = room_kind()
    var already_chosen = chosen(player)
    for row in _rows():
        if row.size() != 4 or int(row[0]) != player or int(row[1]) < 0:
            continue
        var item = _item(int(row[2]))
        var sold = int(row[3]) != 0
        var blocked = already_chosen and not sold
        var available = not sold and not blocked and _eligible(item, player, []) and RunData.get_remaining_max_nb_item(item, player) > 0
        offers.append({"slot": int(row[1]), "item": item, "kind": kind, "currency": currency_for(player), "price": price_for(item, player), "sold": sold, "available": available, "blocked": blocked})
    return offers

static func purchase(player: int, slot: int) -> Dictionary:
    var failure = {"ok": false}
    var kind = room_kind()
    if kind == 0 or player < 0 or player >= RunData.get_player_count() or chosen(player):
        return failure
    var rows = _rows()
    for row in rows:
        if row.size() != 4 or int(row[0]) != player or int(row[1]) != slot or int(row[3]) != 0:
            continue
        var item = _item(int(row[2]))
        if not _eligible(item, player, []) or RunData.get_remaining_max_nb_item(item, player) <= 0:
            return failure
        var price = price_for(item, player)
        if kind == 1 and currency_amount(player) < price:
            return failure
        # Seal both the slot and angel choice before any stat/item signal can
        # re-enter. Two cards pressed in one frame can grant only one choice.
        row[3] = 1
        if kind == 2:
            for sentinel in rows:
                if sentinel.size() == 4 and int(sentinel[0]) == player and int(sentinel[1]) == -1:
                    sentinel[3] = 1
                    break
        elif currency_for(player) == "materials":
            RunData.remove_gold(price, player)
        else:
            # Match native hp_shop's removal and stat listeners directly;
            # never toggle the player's global shop-currency effect.
            RunData.remove_stat(Keys.stat_max_hp_hash, price, player)
        # Keep native purchase duplication effects (e.g. Mirror), while room
        # stock and normal shop/reroll/D6 callbacks remain independent.
        var duplicate_effects = RunData.get_player_effect(Keys.duplicate_item_hash, player).duplicate()
        for effect in duplicate_effects:
            var count = min(int(effect[1]), RunData.get_remaining_max_nb_item(item, player) - 1)
            for _copy in range(max(0, count)):
                var source = RunData.get_player_item(effect[0], player)
                if source != null:
                    RunData.remove_item(source, player)
                RunData.add_item(item, player)
        RunData.add_item(item, player)
        return {"ok": true, "item": item, "price": price, "slot": slot, "kind": kind, "currency": currency_for(player)}
    return failure
