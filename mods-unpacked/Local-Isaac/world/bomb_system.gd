extends Node

const RULES = preload("res://mods-unpacked/Local-Isaac/bomb_rules.gd")
const ROCK_SCENE = preload("res://mods-unpacked/Local-Isaac/world/rock.tscn")
const BOMB_SCENE = preload("res://mods-unpacked/Local-Isaac/world/bomb_projectile.tscn")
const BOMB_ICON = preload("res://mods-unpacked/Local-Isaac/content/bombs/bomb.png")
const ROCK_SHEET = preload("res://mods-unpacked/Local-Isaac/content/bombs/rocks.png")
const EXPLOSION = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const KNIFE_PROJECTILE = preload("res://mods-unpacked/Local-Isaac/world/moms_knife_projectile.tscn")
const PICKUP_VISUAL = preload("res://mods-unpacked/Local-Isaac/world/bomb_pickup.gd")
const PICKAXE_ID = "weapon_local_isaac_broken_pickaxe"

var game
var rocks = []
var cooldowns = [0.0, 0.0, 0.0, 0.0]
var hud_labels = []
var rock_rewards = []
var bomb_bundles = []
var explosions_fired = 0
var auto_enabled = true
var pickaxe_auto_paused = [false, false, false, false]
var knife_next_allowed = [0, 0, 0, 0]
var knife_attacks = []
var combat_time_ms = 0.0
var bomb_pickups = []
var ground_bomb_amount = 1
var ground_bomb_bogo_owner = -1

func _ready() -> void:
    game = get_parent()
    refresh_bomb_pickup_amount()
    var hud = VBoxContainer.new()
    hud.name = "IsaacBombHUD"
    hud.rect_position = Vector2(25, 220)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    game.get_node("UI").add_child(hud)
    for p in RunData.get_player_count():
        # Shop inventory is fixed for this Main/wave. Cache once, so combat
        # never scans weapon data while deciding whether to spend a bomb.
        for carried in RunData.get_player_weapons_ref(p):
            if carried.weapon_id == PICKAXE_ID:
                pickaxe_auto_paused[p] = true
                break
        var row = HBoxContainer.new()
        hud.add_child(row)
        var icon = TextureRect.new()
        icon.texture = BOMB_ICON
        icon.expand = true
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.rect_min_size = Vector2(96, 96)
        row.add_child(icon)
        var label = Label.new()
        label.valign = Label.VALIGN_CENTER
        label.add_font_override("font", load("res://resources/fonts/actual/base/font_40_outline.tres"))
        row.add_child(label)
        hud_labels.append(label)

func _physics_process(delta: float) -> void:
    for p in hud_labels.size():
        hud_labels[p].text = ("P" + str(p + 1) + " " if RunData.get_player_count() > 1 else "") + str(RULES.count(p))
    if not game._cleaning_up:
        attract_bomb_pickups()
    if not game._cleaning_up and RunData.wave_in_progress:
        combat_time_ms += delta * 1000.0
    if game._cleaning_up or not auto_enabled or not RunData.wave_in_progress:
        return
    for p in game._players.size():
        cooldowns[p] = max(0.0, cooldowns[p] - delta)
        var player = game._players[p]
        if pickaxe_auto_paused[p] or player.dead or cooldowns[p] > 0 or RULES.count(p) <= 0:
            continue
        var rock = nearest_rock(player.global_position)
        if rock != null:
            launch(player.global_position, rock, p)
            cooldowns[p] = RULES.AUTO_COOLDOWN

func nearest_rock(pos: Vector2):
    var nearest = null
    var distance = RULES.AUTO_RANGE
    for rock in rocks:
        if not is_instance_valid(rock) or rock.destroyed or rock.reserved:
            continue
        var d = pos.distance_to(rock.global_position)
        if d <= distance:
            nearest = rock
            distance = d
    return nearest

func spawn_rock(pos: Vector2, variant: int = -1) -> Node:
    var rock = ROCK_SCENE.instance()
    rock.system = self
    rock.variant = Utils.randi_range(0, 5) if variant < 0 else variant % 6
    var texture = AtlasTexture.new()
    texture.atlas = ROCK_SHEET
    texture.region = Rect2(rock.variant * 32, 0, 32, 32)
    rock.get_node("Sprite").texture = texture
    game._entities_container.add_child(rock)
    rock.global_position = pos
    rocks.append(rock)
    return rock

func launch(pos: Vector2, rock: Node2D, player_index: int) -> Node:
    if RULES.count(player_index) <= 0 or rock.destroyed or rock.reserved:
        return null
    RULES.change_count(player_index, -1)
    rock.reserved = true
    var bomb = BOMB_SCENE.instance()
    bomb.system = self
    bomb.target = rock
    bomb.last_target_position = rock.global_position
    bomb.player_index = player_index
    game.add_child(bomb)
    bomb.global_position = pos
    return bomb

func detonate(pos: Vector2, player_index: int) -> Node:
    if game._cleaning_up:
        return null
    var args = WeaponServiceExplodeArgs.new()
    args.Reset()
    args.pos = pos
    args.damage = max(1, int(round(RULES.DAMAGE * preload("res://mods-unpacked/Local-Isaac/stat_rules.gd").soy_factor(player_index))))
    args.accuracy = 1.0
    args.crit_chance = 0.0
    args.crit_damage = 1.0
    args.scaling_stats = []
    args.from_player_index = player_index
    var explosion = WeaponService.explode(EXPLOSION, args)
    explosions_fired += 1
    var radius = RULES.explosion_radius(player_index)
    for rock in rocks.duplicate():
        if is_instance_valid(rock) and not rock.destroyed and rock.global_position.distance_to(pos) <= radius:
            rock.break_from_bomb(player_index)
    return explosion

func spawn_bomb_bundle(pos: Vector2, amount: int = -1) -> Array:
    if amount < 0:
        amount = 1
    var data = load("res://mods-unpacked/Local-Isaac/content/bombs/bomb_consumable.tres")
    var pickups = []
    for _i in range(amount):
        pickups.append(spawn_consumable(data, pos))
    bomb_bundles.append([pos, amount])
    return pickups

func refresh_bomb_pickup_amount() -> void:
    # Inventory is fixed during a wave. One team-wide value makes the ground
    # bundle's picture and value identical for every co-op collector.
    ground_bomb_amount = 1
    ground_bomb_bogo_owner = -1
    for p in RunData.get_player_count():
        var amount = RULES.pickup_amount(p)
        if amount > ground_bomb_amount:
            ground_bomb_amount = amount
            ground_bomb_bogo_owner = p

func bomb_pickup_amount(pickup: Node) -> int:
    return int(max(1, int(pickup.get_meta(RULES.PICKUP_AMOUNT_META)))) if pickup.has_meta(RULES.PICKUP_AMOUNT_META) else ground_bomb_amount

func bomb_pickup_bogo_owner(pickup: Node) -> int:
    return int(pickup.get_meta(RULES.PICKUP_BOGO_OWNER_META)) if pickup.has_meta(RULES.PICKUP_BOGO_OWNER_META) else ground_bomb_bogo_owner

func setup_bomb_pickup(pickup: Node) -> void:
    pickup.set_meta(RULES.PICKUP_AMOUNT_META, ground_bomb_amount)
    pickup.set_meta(RULES.PICKUP_BOGO_OWNER_META, ground_bomb_bogo_owner)
    var visual = pickup.get_node_or_null("IsaacBombPickup")
    if visual == null:
        visual = PICKUP_VISUAL.new()
        visual.name = "IsaacBombPickup"
        pickup.add_child(visual)
    pickup.scale = Vector2(2, 2)
    visual.configure(ground_bomb_amount)
    if not bomb_pickups.has(pickup):
        bomb_pickups.append(pickup)

func clear_bomb_pickup(pickup: Node) -> void:
    var visual = pickup.get_node_or_null("IsaacBombPickup")
    if visual == null:
        return
    bomb_pickups.erase(pickup)
    visual.clear()
    pickup.scale = Vector2.ONE
    pickup.attracted_by = null
    pickup.set_physics_process(false)
    if pickup.has_meta(RULES.PICKUP_AMOUNT_META):
        pickup.remove_meta(RULES.PICKUP_AMOUNT_META)
    if pickup.has_meta(RULES.PICKUP_BOGO_OWNER_META):
        pickup.remove_meta(RULES.PICKUP_BOGO_OWNER_META)

func attract_bomb_pickups() -> void:
    for i in range(bomb_pickups.size() - 1, -1, -1):
        var pickup = bomb_pickups[i]
        if not is_instance_valid(pickup) or pickup.already_picked_up or pickup.get_parent() == null:
            bomb_pickups.remove(i)
            continue
        if pickup.push_back or pickup.idle_time_after_pushed_back > 0 or not pickup.monitorable:
            continue
        if is_instance_valid(pickup.attracted_by) and not pickup.attracted_by.dead:
            continue
        var nearest = null
        var distance_squared = RULES.PICKUP_ATTRACT_RANGE * RULES.PICKUP_ATTRACT_RANGE
        for player in game._players:
            if not is_instance_valid(player) or player.dead:
                continue
            var candidate_distance = pickup.global_position.distance_squared_to(player.global_position)
            if candidate_distance < distance_squared:
                nearest = player
                distance_squared = candidate_distance
        if nearest != null:
            # Native Item._physics_process supplies fruit's acceleration and
            # native Player.ItemPickupArea remains the sole pickup trigger.
            pickup.attracted_by = nearest
            pickup.set_physics_process(true)

func spawn_consumable(data: ConsumableData, pos: Vector2) -> Node:
    var pickup = game.get_node_from_pool(game._consumable_pool_id, game._consumables_container)
    if pickup == null:
        pickup = game.consumable_scene.instance()
        game._consumables_container.call_deferred("add_child", pickup)
        pickup.connect("picked_up", game, "on_consumable_picked_up")
        yield(pickup, "ready")
    pickup.already_picked_up = false
    pickup.consumable_data = data
    pickup.set_texture(data.icon)
    pickup.drop(pos, 0, ZoneService.get_rand_pos_in_area(pos, 65, 0))
    if data.my_id == RULES.CONSUMABLE:
        setup_bomb_pickup(pickup)
    game._consumables.append(pickup)
    return pickup

func on_rock_broken(pos: Vector2, player_index: int) -> void:
    var amount = RULES.rock_bomb_amount()
    spawn_bomb_bundle(pos, amount)
    game.spawn_gold(20, pos, 75)
    var dropped_chest = false
    var luck = Utils.sum_all_player_stats(Keys.stat_luck_hash) / 100.0
    var tree_stats = load("res://mods-unpacked/Local-Isaac/scenery_rules_032.gd").current_tree_stats()
    var item_chance = tree_stats.item_drop_chance * (1.0 + luck) / (1.0 + game._items_spawned_this_wave) if tree_stats != null else 0.0
    item_chance *= 1.0 + RunData.sum_all_player_effects(Keys.crate_chance_hash) / 100.0
    var drop_chance = min(1.0, tree_stats.base_drop_chance * (1.0 + luck)) if tree_stats != null else 0.0
    if RunData.current_wave > RunData.nb_of_waves:
        drop_chance /= 1.0 + RunData.get_endless_factor()
    if DebugService.always_drop_crates:
        drop_chance = 1.0
        item_chance = 1.0
    if Utils.get_chance_success(drop_chance) and Utils.get_chance_success(item_chance):
        spawn_consumable(ItemService.get_consumable_for_tier(Tier.UNCOMMON), pos)
        game._items_spawned_this_wave += 1
        dropped_chest = true
    rock_rewards.append([amount, 20, dropped_chest, player_index])

func on_weapon_attack(weapon: Weapon) -> void:
    if game._cleaning_up or not RunData.wave_in_progress:
        return
    var p = weapon.player_index
    if p < 0 or p >= game._players.size() or weapon._parent != game._players[p]:
        return
    var multiplier = RULES.knife_multiplier(p)
    var effects = RunData.get_player_effects(p)
    var key = Keys.generate_hash(RULES.KNIFE_PROGRESS)
    if multiplier == 0:
        effects[key] = 0
        return
    effects[key] = min(RULES.KNIFE_ATTACKS, effects[key] + 1)
    if effects[key] < RULES.KNIFE_ATTACKS or combat_time_ms < knife_next_allowed[p]:
        return
    effects[key] = 0
    knife_next_allowed[p] = combat_time_ms + RULES.KNIFE_COOLDOWN_MS
    var highest = 0
    for carried in game._players[p].current_weapons:
        highest = max(highest, carried.current_stats.damage)
    var damage = int(ceil(highest * multiplier))
    if damage <= 0:
        return
    var stats = RangedWeaponStats.new()
    stats.damage = damage
    stats.accuracy = 1.0
    stats.crit_chance = 0.0
    stats.crit_damage = 1.0
    stats.scaling_stats = []
    stats.projectile_speed = 1400
    stats.max_range = 10000
    stats.piercing = 999999
    stats.piercing_dmg_reduction = 0.0
    stats.bounce = 0
    stats.projectile_scene = KNIFE_PROJECTILE
    var target_pos = Vector2.ZERO
    var has_target = not weapon._manual_aim and weapon._current_target.size() > 0 and is_instance_valid(weapon._current_target[0])
    if has_target:
        var target = weapon._current_target[0]
        var hurtbox = target.get_node_or_null("Hurtbox")
        target_pos = hurtbox.global_position if hurtbox != null else target.global_position
    # Every equipped weapon contributes one projectile, for either trigger type.
    # Use the triggering attack's target so mixed loadouts share the same aim.
    for carried in game._players[p].current_weapons:
        var pos = carried.muzzle.global_position
        var direction = (target_pos - pos).angle() if has_target else weapon.rotation
        var args = WeaponServiceSpawnProjectileArgs.new()
        args.from_player_index = p
        args.damage_tracking_key_hash = Keys.generate_hash(RULES.KNIFE_ID)
        var knife = WeaponService.spawn_projectile(pos, stats, direction, game._players[p], args)
        knife_attacks.append(["ranged", damage, p, knife])
