extends "res://main.gd"

const ISAAC_BOMBS = preload("res://mods-unpacked/Local-Isaac/bomb_rules.gd")
var isaac_bomb_system: Node = null
var isaac_gemini: Node = null
var isaac_keeper_rules = null

func _ready() -> void:
    # Load the character-specific cleanup only when a Keeper is in this wave.
    for player in RunData.get_player_count():
        var character = RunData.get_player_character(player)
        if character != null and character.my_id == "character_local_keeper":
            isaac_keeper_rules = load("res://mods-unpacked/Local-Isaac/keeper_rules_039.gd")
            break
    isaac_ensure_bomb_system()
    if isaac_gemini == null:
        isaac_gemini = load("res://mods-unpacked/Local-Isaac/world/gemini.gd").new()
        isaac_gemini.name = "IsaacGemini"
        add_child(isaac_gemini)

func isaac_ensure_bomb_system() -> void:
    if isaac_bomb_system != null:
        return
    isaac_bomb_system = load("res://mods-unpacked/Local-Isaac/world/bomb_system.gd").new()
    isaac_bomb_system.name = "IsaacBombSystem"
    add_child(isaac_bomb_system)

func isaac_spawn_rock(pos: Vector2, variant: int = -1) -> Node:
    isaac_ensure_bomb_system()
    return isaac_bomb_system.spawn_rock(pos, variant)

func spawn_loot(unit: Unit, entity_type: int, args: Entity.DieArgs) -> void:
    .spawn_loot(unit, entity_type, args)
    if _cleaning_up or not unit.can_drop_loot or isaac_bomb_system == null:
        return
    if entity_type == EntityType.ENEMY or entity_type == EntityType.NEUTRAL:
        if Utils.get_chance_success(ISAAC_BOMBS.drop_chance(entity_type == EntityType.NEUTRAL)):
            isaac_bomb_system.spawn_bomb_bundle(unit.global_position, 1)

func clean_up_room() -> void:
    if isaac_keeper_rules != null:
        isaac_clean_up_keeper_materials()
    .clean_up_room()

func isaac_clean_up_keeper_materials() -> void:
    var keepers = isaac_keeper_rules.keeper_players()
    if not keepers.empty():
        # Filter before either native cleanup mode attracts/converts the
        # shared ground materials. Never clear the global bonus-gold bag.
        var next_player = _next_gold_player
        for gold in _active_golds.duplicate():
            var original_value = int(gold.value)
            var remaining = isaac_keeper_rules.remaining_materials(original_value, next_player, keepers)
            next_player = (next_player + original_value) % keepers.size()
            if remaining <= 0:
                gold.already_picked_up = true
                gold.reset()
                _active_golds.erase(gold)
                add_node_to_pool(gold, _gold_pool_id)
            else:
                gold.value = remaining

func on_consumable_picked_up(consumable: Node, player_index: int) -> void:
    var is_bomb = not consumable.already_picked_up and consumable.consumable_data.my_id == ISAAC_BOMBS.CONSUMABLE
    # Capture before the native handler returns this node to the shared pool.
    # Its value belongs to the ground bundle, not to the collecting player.
    var extra = max(0, isaac_bomb_system.bomb_pickup_amount(consumable) - 1) if is_bomb else 0
    var bogo_owner = isaac_bomb_system.bomb_pickup_bogo_owner(consumable) if is_bomb else -1
    .on_consumable_picked_up(consumable, player_index)
    if is_bomb:
        ISAAC_BOMBS.change_count(player_index, extra)
        if extra > 0 and bogo_owner >= 0 and bogo_owner < RunData.get_player_count():
            RunData.add_tracked_value(bogo_owner, Keys.generate_hash(ISAAC_BOMBS.BOGO_ID), extra)

func isaac_ipecac_explosion_hit(target: Node, _damage: int, data: Dictionary) -> void:
    # The doubled explosion has no melee marker. Attribute its actual dealt
    # damage once, including a lethal hit where no DOT can be applied.
    if data.get("tough", false) and _damage > 0:
        RunData.add_tracked_value(int(data.player), Keys.generate_hash("item_local_isaac_tough_love"), int(_damage / 2))
    var is_poison = bool(data.get("poison", true))
    if not target is Enemy or target.dead or target._pending_die or target.get_charmed_by_player_index() >= 0:
        return
    if not is_poison and RunData.get_player_effect(Keys.can_burn_enemies_hash, int(data.player)) <= 0:
        return
    var status = data.get("status", "IsaacIpecacPoison")
    var duration = int(data.get("duration", 5))
    var tracking = data.get("tracking", Keys.empty_hash)
    if tracking is String:
        tracking = Keys.generate_hash(tracking)
    var burn = target.get_node_or_null(status)
    if burn != null and not burn.is_queued_for_deletion():
        var replacing = int(data.burn_damage) >= burn.damage
        burn.refresh(int(data.burn_damage), int(data.player), float(data.get("burn_scaling", 0.5)), duration, int(tracking))
        if replacing:
            burn.pet_damage = bool(data.get("pet_damage", false))
    else:
        burn = load("res://mods-unpacked/Local-Isaac/world/ipecac_burn.gd").new()
        burn.name = status
        burn.is_poison = is_poison
        burn.duration = duration
        burn.pet_damage = bool(data.get("pet_damage", false))
        burn.damage = int(data.burn_damage)
        burn.owner_index = int(data.player)
        burn.scaling = float(data.get("burn_scaling", 0.5))
        burn.tracking_key = int(tracking)
        target.add_child(burn)

func isaac_baby_explode(pos: Vector2, data: Dictionary) -> void:
    load("res://mods-unpacked/Local-Isaac/baby_rules.gd").explode_at(pos, data)

func add_node_to_pool(node: Node, id: int) -> void:
    if id == _consumable_pool_id and isaac_bomb_system != null and node.has_node("IsaacBombPickup"):
        isaac_bomb_system.clear_bomb_pickup(node)
    # Preserve compiled Projectile subclasses. Restoring through Main's pool
    # entry runs before the next native shoot() recalculates dynamic visuals.
    load("res://mods-unpacked/Local-Isaac/pet_bonus.gd").restore_projectile_visual(node)
    load("res://mods-unpacked/Local-Isaac/world/attack_utility.gd").clear(node)
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_attack_meta(node.get("_hitbox"))
    .add_node_to_pool(node, id)

func _on_neutral_died(neutral: Neutral, args: Entity.DieArgs) -> void:
    if neutral.has_meta("isaac_leo_owner"):
        var p = int(neutral.get_meta("isaac_leo_owner"))
        neutral.remove_meta("isaac_leo_owner")
        if p >= 0 and p < _players.size() and is_instance_valid(_players[p]):
            var owned_args = Entity.DieArgs.new()
            for prop in args.get_property_list():
                if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "script":
                    owned_args.set(prop.name, args.get(prop.name))
            owned_args.from = _players[p]
            owned_args.killed_by_player_index = p
            owned_args.enemy_killed_by_player = true
            args = owned_args
    ._on_neutral_died(neutral, args)
