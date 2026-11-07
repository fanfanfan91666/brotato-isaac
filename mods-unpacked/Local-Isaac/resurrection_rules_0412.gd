extends Reference

const SHADOW_ID = "item_local_isaac_judas_shadow"
const FORGET_ID = "item_local_isaac_forget_me_now"
const META = "local_isaac_resurrection_0412"
const PENDING_META = "local_isaac_rewind_scheduled_0412"

# All persisted rows contain only numbers: [version, rewind_wave, players].
# Each player's acquisition ledger is [token, damage_bonus, spent, owned].
# Retaining the used item also retains the native unique-item shop limit.
static func state() -> Array:
    if not RunData.has_meta(META):
        RunData.set_meta(META, [1, 0, [[], [], [], []]])
    return RunData.get_meta(META)

static func get_state() -> Array:
    return state().duplicate(true)

static func reset_state() -> void:
    RunData.set_meta(META, [1, 0, [[], [], [], []]])
    RunData.set_meta(PENDING_META, false)

static func spent_bonus(rows: Array) -> int:
    var total = 0
    for row in rows:
        if row is Array and row.size() >= 4 and int(row[2]) > 0:
            total += int(row[1])
    return total

static func normalized_rows(rows) -> Array:
    var result = [[], [], [], []]
    if not rows is Array:
        return result
    for p in min(4, rows.size()):
        if not rows[p] is Array:
            continue
        for row in rows[p]:
            if not row is Array or row.size() < 4:
                continue
            result[p].append([int(row[0]), max(0, int(row[1])), int(int(row[2]) > 0), int(int(row[3]) > 0)])
    return result

static func restore_state(saved: Array) -> void:
    var previous = normalized_rows(state()[2])
    var incoming = normalized_rows(saved[2] if saved.size() >= 3 and int(saved[0]) == 1 else [])
    var merged = incoming.duplicate(true)
    for p in 4:
        for old_row in previous[p]:
            var found = false
            for row in merged[p]:
                if row[0] == old_row[0]:
                    # Retry-wave snapshots may precede this death. A spent
                    # acquisition stays spent for the whole run.
                    row[2] = max(int(row[2]), int(old_row[2]))
                    found = true
                    break
            if not found:
                # A rolled-back acquisition no longer owns a usable charge,
                # but an already-earned permanent bonus is still permanent.
                merged[p].append([old_row[0], old_row[1], old_row[2], 0])
    var pending_wave = max(0, int(saved[1])) if saved.size() >= 3 and int(saved[0]) == 1 else 0
    RunData.set_meta(META, [1, pending_wave, merged])
    RunData.set_meta(PENDING_META, false)
    for p in RunData.get_player_count():
        var missing_bonus = spent_bonus(merged[p]) - spent_bonus(incoming[p])
        if missing_bonus != 0:
            RunData.add_stat(Keys.stat_percent_damage_hash, missing_bonus, p)

static func item_added(item, player_index: int) -> void:
    if item.my_id != SHADOW_ID or player_index < 0 or player_index >= 4:
        return
    var rows = state()[2][player_index]
    var token = 1
    for row in rows:
        token = max(token, int(row[0]) + 1)
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var bonus = int(curses.params("judas_shadow", curses.item_factor(item)).damage)
    rows.append([token, bonus, 0, 1])

static func item_removed(item, player_index: int, _by_id: bool = false) -> void:
    if item.my_id != SHADOW_ID or player_index < 0 or player_index >= 4:
        return
    # This item is unique. Normal resurrection keeps its used inventory icon;
    # an explicit removal revokes only the acquisition's remaining charge.
    for row in state()[2][player_index]:
        if int(row[3]) > 0:
            row[3] = 0
            break

static func has_charge(player_index: int) -> bool:
    if player_index < 0 or player_index >= RunData.get_player_count():
        return false
    for row in state()[2][player_index]:
        if int(row[2]) == 0 and int(row[3]) > 0:
            return true
    return false

static func try_revive(player, args) -> bool:
    if args.cleaning_up or not RunData.wave_in_progress or player.dead or player.current_stats.health > 0:
        return false
    var p = int(player.player_index)
    if p < 0 or p >= RunData.get_player_count():
        return false
    for row in state()[2][p]:
        if int(row[2]) > 0 or int(row[3]) <= 0:
            continue
        # Consume synchronously before restoring HP. Intercepting before the
        # parent die() keeps native collisions, weapons and signals alive;
        # native Player.respawn() intentionally asserts and is never used.
        row[2] = 1
        RunData.add_stat(Keys.stat_percent_damage_hash, int(row[1]), p)
        checkpoint_spent_charge()
        player.update_player_stats(false)
        player._pending_die = false
        player.current_stats.health = int(max(1, int(player.max_stats.health)))
        RunData.players_data[p].current_health = player.current_stats.health
        player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)
        return true
    return false

static func update_checkpoint(snapshot: Dictionary) -> void:
    if not snapshot.has("players_data"):
        return
    var old = snapshot.get("isaac_resurrection_rows_0412", [])
    var old_rows = normalized_rows(old[2] if old is Array and old.size() >= 3 else [])
    var current = state()
    # Native checkpoint dictionaries can be shallow copies of one another.
    # Isolate this array and each player we alter before touching its effects;
    # native PlayerRunData.duplicate() deep-copies that effects dictionary.
    var checkpoint_players = snapshot.players_data.duplicate()
    for p in min(checkpoint_players.size(), 4):
        var difference = spent_bonus(current[2][p]) - spent_bonus(old_rows[p])
        if difference != 0:
            checkpoint_players[p] = checkpoint_players[p].duplicate()
            var effects = checkpoint_players[p].effects
            effects[Keys.stat_percent_damage_hash] = int(effects.get(Keys.stat_percent_damage_hash, 0)) + difference
    snapshot.players_data = checkpoint_players
    var checkpoint_rows = current.duplicate(true)
    if old is Array and old.size() >= 3:
        # A saved shop's pending replay is its normal resume destination.
        # Spending a shadow during that battle must not erase that marker.
        checkpoint_rows[1] = max(0, int(old[1]))
    snapshot.isaac_resurrection_rows_0412 = checkpoint_rows

static func checkpoint_spent_charge() -> void:
    # Native retries re-save last_saved_run_state; a mere in-memory ledger
    # would therefore grant the life again after quitting and reloading.
    # Update only this item's ledger and earned Damage on those pre-existing
    # checkpoints, preserving the native rollback of all battle earnings.
    update_checkpoint(RunData.start_wave_state)
    if ProgressData.saved_run_state is Dictionary:
        update_checkpoint(ProgressData.saved_run_state)
    if ProgressData.last_saved_run_state is Dictionary:
        update_checkpoint(ProgressData.last_saved_run_state)
    ProgressData.save()

static func request_rewind(shop) -> bool:
    if not is_instance_valid(shop) or not shop.is_inside_tree() or RunData.current_wave < 1:
        return false
    if RunData.has_meta(PENDING_META) and bool(RunData.get_meta(PENDING_META)):
        return false
    var current = state()
    if int(current[1]) <= 0:
        var found = false
        for p in RunData.get_player_count():
            var item = RunData.get_player_item(Keys.generate_hash(FORGET_ID), p)
            if item != null:
                RunData.remove_item(item, p)
                found = true
                break
        if not found:
            return false
        current[1] = RunData.current_wave
    # Purchase callbacks still refresh UI and save the sold room row. Defer
    # the scene change until that stack has completed, exactly once per shop.
    RunData.set_meta(PENDING_META, true)
    var transition = load("res://mods-unpacked/Local-Isaac/world/forget_rewind_0412.gd").new()
    transition.name = "IsaacForgetRewind"
    transition.shop = weakref(shop)
    shop.get_tree().root.add_child(transition)
    transition.call_deferred("begin")
    return true

static func take_pending_wave() -> int:
    var current = state()
    var wave = int(current[1])
    current[1] = 0
    RunData.set_meta(PENDING_META, false)
    return wave
