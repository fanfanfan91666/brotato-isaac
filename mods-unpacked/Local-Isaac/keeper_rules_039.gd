extends Reference

const CHARACTER_ID = "character_local_keeper"

static func is_keeper(player: int) -> bool:
    if player < 0 or player >= RunData.get_player_count():
        return false
    var character = RunData.get_player_character(player)
    return character != null and character.my_id == CHARACTER_ID

static func keeper_players() -> Array:
    var players = []
    var found = false
    for player in RunData.get_player_count():
        var keeper = is_keeper(player)
        players.append(keeper)
        found = found or keeper
    return players if found else []

static func remaining_materials(value: int, first_player: int, keepers: Array) -> int:
    if value <= 0 or keepers.empty():
        return int(max(0, value))
    # Ground materials and the next-wave bag are native shared resources.
    # Assign each unit in the native pickup round-robin order and discard only
    # Keeper's share. Other players keep their own full uncollected share.
    var count = keepers.size()
    var whole_rounds = int(value / count)
    var removed = 0
    for keeper in keepers:
        if keeper:
            removed += whole_rounds
    for offset in range(value % count):
        if keepers[(first_player + offset) % count]:
            removed += 1
    return value - removed
