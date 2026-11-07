extends Reference

# RunData metadata is session storage. The run-state extension saves only these
# numeric rows, outside Player.effects and its schema/hash conversion.
const META = "isaac_special_room_rows_034"
const VERSION = 3
# Physical card limit; a fresh inventory samples two, three or four entries.
const OFFER_COUNT = 4
const CHANCE_META = "isaac_room_chance_rows_0412"
const CHANCE_VERSION = 1
const DEVIL_CHANCE_STAT = "stat_local_isaac_devil_room_chance"
const ANGEL_CHANCE_STAT = "stat_local_isaac_angel_room_chance"
const DAMAGE_CHANCES = [100, 88, 66, 33, 11, 1, 0]
const DEVIL_ONLY = ["incubus", "succubus", "money_equals_power", "nightmare", "pound_of_flesh", "lusty_blood", "dark_matter", "forget_me_now", "judas_shadow", "goat_head", "sin_twins", "bloody_gust"]
const DEVIL_AND_SHOP = ["moms_knife", "ghost_baby", "abaddon_baby", "demon_baby"]
const SHARED_ROOMS = ["duality"]
const ANGEL_ONLY = ["light_crown", "holy_wafer", "seraphim", "divine_barrier", "eucharist", "blood_of_martyr", "halo", "jesus_juice", "guardian_angel"]

static func room_kind(wave: int = -1) -> int:
    var completed_wave = RunData.current_wave if wave < 0 else wave
    if completed_wave <= 0 or completed_wave % 3 != 0:
        return 0
    return 1 if int(completed_wave / 3) % 2 == 1 else 2

static func title_key(wave: int = -1, kind: int = -1) -> String:
    return "LOCAL_ISAAC_DEVIL_ROOM" if (room_kind(wave) if kind < 0 else kind) == 1 else "LOCAL_ISAAC_ANGEL_ROOM"

static func kinds_for(player: int) -> Array:
    var scheduled = room_kind()
    if scheduled == 0:
        return []
    if RunData.get_nb_item(Keys.generate_hash("item_local_isaac_duality"), player) > 0:
        return [1, 2]
    var selected = selected_kind(player)
    if selected > 0 and selected != scheduled:
        return [scheduled, selected]
    return [scheduled]

static func stock_key(player: int, kind: int) -> int:
    return player * 2 + kind - 1

static func selected_kind(player: int) -> int:
    for row in _rows():
        if row.size() == 4 and int(row[0]) == player * 2 and int(row[1]) == -2:
            return int(row[2])
    return 0

static func enter_room(player: int, kind: int) -> bool:
    if not room_available(player, kind):
        return false
    if selected_kind(player) == 0:
        _rows().append([player * 2, -2, kind, 0])
    return true

static func reset_state() -> void:
    RunData.set_meta(META, [])
    RunData.set_meta(CHANCE_META, [])

static func is_devil_only(item: Resource) -> bool:
    return item != null and item.my_id.begins_with("item_local_isaac_") and item.my_id.replace("item_local_isaac_", "") in DEVIL_ONLY

static func is_angel_only(item: Resource) -> bool:
    return item != null and item.my_id.begins_with("item_local_isaac_") and item.my_id.replace("item_local_isaac_", "") in ANGEL_ONLY

static func is_room_only(item: Resource) -> bool:
    return is_devil_only(item) or is_angel_only(item) or (item != null and item.my_id == "item_local_isaac_duality")

static func in_room_pool(item: Resource, kind: int = -1) -> bool:
    if item == null or not item.my_id.begins_with("item_local_isaac_"):
        return false
    var actual_kind = room_kind() if kind < 0 else kind
    var name = item.my_id.replace("item_local_isaac_", "")
    if actual_kind == 1:
        return name in DEVIL_ONLY or name in DEVIL_AND_SHOP or name in SHARED_ROOMS
    return actual_kind == 2 and (name in ANGEL_ONLY or name in SHARED_ROOMS)

static func is_chance_stat(stat_hash: int) -> bool:
    return stat_hash == Keys.generate_hash(DEVIL_CHANCE_STAT) or stat_hash == Keys.generate_hash(ANGEL_CHANCE_STAT)

static func _chance_rows() -> Array:
    var rows = RunData.get_meta(CHANCE_META) if RunData.has_meta(CHANCE_META) else []
    if not rows is Array or rows.empty() or not _numeric_row(rows[0], 2) or int(rows[0][0]) != CHANCE_VERSION or int(rows[0][1]) != RunData.current_wave:
        return []
    return rows

static func get_chance_state() -> Array:
    return _chance_rows().duplicate(true)

static func restore_chance_state(saved_rows: Array) -> void:
    # Native resume replaces PlayerRunData without clearing item-count caches.
    # Refresh this one toggle once, including checkpoint/coop restoration.
    for player in RunData.get_player_count():
        for name in ["eucharist", "goat_head", "duality"]:
            RunData.get_nb_item(Keys.generate_hash("item_local_isaac_" + name), player, false)
    var rows = []
    if not saved_rows.empty() and _numeric_row(saved_rows[0], 2) and int(saved_rows[0][0]) == CHANCE_VERSION and int(saved_rows[0][1]) == RunData.current_wave:
        rows = [[CHANCE_VERSION, RunData.current_wave]]
        var seen = {}
        for index in range(1, saved_rows.size()):
            var raw = saved_rows[index]
            if not _numeric_row(raw, 3):
                continue
            var player = int(raw[0])
            if player < 0 or player >= 4 or seen.has(player):
                continue
            seen[player] = true
            rows.append([player, int(clamp(int(raw[1]), 0, 6)), int(clamp(int(raw[2]), -1, 1))])
    # V1/V2 stock already generated before chances existed remains usable.
    # Loading never samples replacement stock or grants any item.
    if rows.empty() and room_kind() != 0:
        var stock_owners = {}
        for stock in _rows():
            if stock.size() == 4 and int(stock[1]) == -1:
                if rows.empty():
                    rows.append([CHANCE_VERSION, RunData.current_wave])
                var owner = int(int(stock[0]) / 2)
                if not stock_owners.has(owner):
                    rows.append([owner, 0, 1])
                    stock_owners[owner] = true
    RunData.set_meta(CHANCE_META, rows)

static func begin_wave() -> void:
    var rows = [[CHANCE_VERSION, RunData.current_wave]]
    for player in RunData.get_player_count():
        rows.append([player, 0, -1])
    RunData.set_meta(CHANCE_META, rows)
    for player in RunData.get_player_count():
        Utils.reset_stat_cache(player)

static func chance_after_damage(hits: int) -> int:
    return int(DAMAGE_CHANCES[int(clamp(hits, 0, 6))])

static func scheduled_guarantee(player: int) -> bool:
    var kind = room_kind()
    if kind == 0 or player < 0 or player >= RunData.get_player_count():
        return false
    var name = "goat_head" if kind == 1 else "eucharist"
    return RunData.get_nb_item(Keys.generate_hash("item_local_isaac_" + name), player) > 0

static func chance_for(player: int, kind: int) -> int:
    if player < 0 or player >= RunData.get_player_count() or not kind in kinds_for(player):
        return 0
    if scheduled_guarantee(player):
        return 100
    for row in _chance_rows():
        if row.size() == 3 and int(row[0]) == player:
            return chance_after_damage(int(row[1]))
    return 0

static func chance_stat(stat_hash: int, player: int) -> float:
    return float(chance_for(player, 1 if stat_hash == Keys.generate_hash(DEVIL_CHANCE_STAT) else 2))

static func note_damage(player: int) -> void:
    if not RunData.wave_in_progress or room_kind() == 0 or scheduled_guarantee(player):
        return
    for row in _chance_rows():
        if row.size() == 3 and int(row[0]) == player and int(row[2]) == -1 and int(row[1]) < 6:
            row[1] = int(min(6, int(row[1]) + 1))
            Utils.reset_stat_cache(player)
            return

static func complete_wave() -> void:
    if room_kind() == 0:
        return
    for row in _chance_rows():
        if row.size() == 3 and int(row[2]) == -1:
            var chance = chance_for(int(row[0]), room_kind())
            # Endpoints are exact even if the random float includes 1.0.
            row[2] = 1 if chance >= 100 or (chance > 0 and randf() * 100.0 < chance) else 0

static func room_available(player: int, kind: int = -1) -> bool:
    kind = room_kind() if kind < 0 else kind
    if room_kind() == 0 or player < 0 or player >= RunData.get_player_count():
        return false
    if not kind in kinds_for(player) or not selected_kind(player) in [0, kind]:
        return false
    for row in _chance_rows():
        if row.size() == 3 and int(row[0]) == player:
            return int(row[2]) == 1
    return false

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
    elif int(rows[0][0]) in [1, 2]:
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
    if not old_version in [1, 2, VERSION] or int(saved_rows[0][1]) != RunData.current_wave:
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
        if old_version < 3:
            if player < 0 or player >= 4:
                continue
            player = stock_key(player, room_kind())
        if player < 0 or player >= 8 or slot < -2 or slot >= OFFER_COUNT:
            continue
        if slot == -2:
            if old_version == 3 and player % 2 == 0 and int(raw[2]) in [1, 2] and not seen.has(player * 8 - 1):
                rows.append([player, -2, int(raw[2]), 0])
                seen[player * 8 - 1] = true
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
        if player % 2 == 1 and sold_players.has(player):
            sentinels[player][3] = 1
    return rows

static func offer_count_from(value: float) -> int:
    if value < 0.5:
        return 4
    return 2 if value < 0.75 else 3

static func currency_amount(player: int, kind: int = -1) -> int:
    kind = room_kind() if kind < 0 else kind
    if kind != 1 or player < 0 or player >= RunData.get_player_count():
        return 0
    if currency_for(player, kind) == "materials":
        return RunData.get_player_gold(player)
    # Native Demon uses uncapped get_stat rather than displayed/effective HP.
    return RunData.get_stat(Keys.stat_max_hp_hash, player) as int

static func currency_for(player: int, kind: int = -1) -> String:
    kind = room_kind() if kind < 0 else kind
    if kind != 1:
        return "free"
    if player < 0 or player >= RunData.get_player_count():
        return "hp"
    var character = RunData.get_player_character(player)
    var keeper = character != null and character.my_id == "character_local_keeper"
    var pound_of_flesh = RunData.get_nb_item(Keys.generate_hash("item_local_isaac_pound_of_flesh"), player) > 0
    return "materials" if keeper or pound_of_flesh else "hp"

static func price_for(item: Resource, player: int, kind: int = -1) -> int:
    kind = room_kind() if kind < 0 else kind
    if kind != 1 or item == null or player < 0 or player >= RunData.get_player_count():
        return 0
    var value = ItemService.get_value(RunData.current_wave, item.value, player, true, false, item.my_id_hash)
    if currency_for(player, kind) == "materials":
        return value
    return ceil(value / 20.0) as int

static func chosen(player: int, kind: int = -1) -> bool:
    kind = room_kind() if kind < 0 else kind
    if kind != 2 or player < 0 or player >= RunData.get_player_count():
        return false
    for row in _rows():
        if row.size() == 4 and int(row[0]) == stock_key(player, kind) and int(row[3]) != 0:
            return true
    return false

static func _item(id: int) -> Resource:
    # Missing/removed mods must not turn an existing slot into a fresh roll.
    for item in ItemService.items:
        if item.my_id_hash == id:
            return item
    return null

static func _eligible(item: Resource, player: int, reserved: Array) -> bool:
    if item == null or not item is ItemData or item is WeaponData or (not item.can_be_looted and not is_room_only(item)) or item.max_nb == 0:
        return false
    if RunData.current_difficulty < item.minimum_difficulty:
        return false
    if not ProgressData.items_unlocked.has(item.my_id_hash):
        return false
    for banned in RunData.players_data[player].banned_items:
        if banned == item.my_id_hash or banned == item.my_id:
            return false
    var character = RunData.get_player_character(player)
    if RunData.current_wave < RunData.nb_of_waves:
        if character != null:
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
    if item.max_nb < 0:
        return true
    var remaining = RunData.get_remaining_max_nb_item(item, player)
    var descendants = ItemService.get_limited_item_descendants(item.my_id_hash)
    for other in reserved:
        if other != null and (other.my_id_hash == item.my_id_hash or descendants.has(other.my_id_hash)):
            remaining -= 1
    return remaining > 0

static func ensure_inventory(player: int, normal_shop_items: Array = [], kind: int = -1) -> Array:
    kind = room_kind() if kind < 0 else kind
    if not room_available(player, kind):
        return []
    var rows = _rows()
    for row in rows:
        if row.size() == 4 and int(row[0]) == stock_key(player, kind) and int(row[1]) >= -1:
            return get_offers(player, kind)
    # The sentinel stores the sampled count and angel choice, including when
    # every legal tier is exhausted. Re-entry and save/resume never resample.
    var offer_count = offer_count_from(randf())
    rows.append([stock_key(player, kind), -1, offer_count, 0])
    var registered_items = []
    for item in load("res://mods-unpacked/Local-Isaac/NewContentData.tres").items:
        if item is ItemData and not item is WeaponData:
            registered_items.append(item)
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
            # The room pool is independent from normal shop/crate pools, from
            # which room-only items are deliberately removed. Existing saved
            # slots bypass this new-inventory filter and retain their items.
            for item in registered_items:
                if item.tier == candidate_tier and in_room_pool(item, kind) and _eligible(item, player, reserved) and not selected.has(item.my_id_hash):
                    candidates.append(item)
            if not candidates.empty():
                break
        if candidates.empty():
            break
        var character = RunData.get_player_character(player)
        var wanted_chance = ItemService.CHANCE_WANTED_ITEM_TAG
        if RunData.get_player_effects(player).has(Keys.stat_boosted_wanted_item_tag_hash) and RunData.get_player_effect_bool(Keys.stat_boosted_wanted_item_tag_hash, player):
            wanted_chance = ItemService.BOOSTED_WANTED_ITEM_TAG
        if character != null and Utils.get_chance_success(wanted_chance) and not character.wanted_tags.empty():
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
        rows.append([stock_key(player, kind), slot, item.my_id_hash, 0])
        selected.append(item.my_id_hash)
        reserved.append(item)
    return get_offers(player, kind)

static func get_offers(player: int, kind: int = -1) -> Array:
    kind = room_kind() if kind < 0 else kind
    if not room_available(player, kind):
        return []
    var offers = []
    var already_chosen = chosen(player, kind)
    for row in _rows():
        if row.size() != 4 or int(row[0]) != stock_key(player, kind) or int(row[1]) < 0:
            continue
        var item = _item(int(row[2]))
        var sold = int(row[3]) != 0
        var blocked = already_chosen and not sold
        var available = not sold and not blocked and _eligible(item, player, [])
        offers.append({"slot": int(row[1]), "item": item, "kind": kind, "currency": currency_for(player, kind), "price": price_for(item, player, kind), "sold": sold, "available": available, "blocked": blocked})
    return offers

static func purchase(player: int, slot: int, kind: int = -1) -> Dictionary:
    kind = room_kind() if kind < 0 else kind
    var failure = {"ok": false}
    if not room_available(player, kind) or chosen(player, kind):
        return failure
    var rows = _rows()
    for row in rows:
        if row.size() != 4 or int(row[0]) != stock_key(player, kind) or int(row[1]) != slot or int(row[3]) != 0:
            continue
        var item = _item(int(row[2]))
        if not _eligible(item, player, []):
            return failure
        var price = price_for(item, player, kind)
        var currency = currency_for(player, kind)
        if kind == 1 and currency_amount(player, kind) < price:
            return failure
        # Seal both the slot and angel choice before any stat/item signal can
        # re-enter. Two cards pressed in one frame can grant only one choice.
        row[3] = 1
        if kind == 2:
            for sentinel in rows:
                if sentinel.size() == 4 and int(sentinel[0]) == stock_key(player, kind) and int(sentinel[1]) == -1:
                    sentinel[3] = 1
                    break
        elif currency == "materials":
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
                if source == null:
                    break
                RunData.remove_item(source, player)
                RunData.add_item(item, player)
        RunData.add_item(item, player)
        return {"ok": true, "item": item, "price": price, "slot": slot, "kind": kind, "currency": currency}
    return failure
