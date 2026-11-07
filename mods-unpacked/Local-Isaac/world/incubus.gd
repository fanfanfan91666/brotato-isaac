extends "res://entities/units/pet/pet.gd"

const MOTION = preload("res://mods-unpacked/Local-Isaac/world/pet_motion.gd")
const RANGED_COPY = preload("res://mods-unpacked/Local-Isaac/world/incubus_ranged_weapon.gd")
const MELEE_COPY = preload("res://mods-unpacked/Local-Isaac/world/incubus_melee_weapon.gd")
const ORBIT_RADIUS = 115.0
const ORBIT_SPEED = TAU / 6.0

var auto_fire = true
var copied_weapon: Weapon
var source_weapon: Weapon
var orbit_angle = 0.0
var isaac_copy_kind = "incubus"
var isaac_damage_factor = 1.0
var isaac_winged = true
var sync_left = 0.0
var shots_fired = 0
var last_projectiles = []
var motion: Node
var fallback_weapon: Weapon
var curse_factor = 0.0

func _ready() -> void:
    _hurtbox.set_deferred("monitoring", false)
    _can_move = false
    can_drop_loot = false
    # Keep the native pet detection layer for other pets' Area2D queries;
    # a zero movement mask plus shared collision exceptions prevents crowding.
    collision_layer = 512
    collision_mask = 0
    _animation_player.play("idle")
    motion = MOTION.attach(self, $Animation/Sprite, isaac_winged, 0.28)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    curse_factor = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").effect_factor(effect, player_index, isaac_copy_kind)
    _can_move = false
    can_drop_loot = false
    orbit_angle = -PI / 2.0
    update_orbit(0.0)
    refresh_copy(true)

func owner_player():
    if player_index >= 0 and player_index < players_ref.size() and is_instance_valid(players_ref[player_index]):
        return players_ref[player_index]
    return null

func highest_weapon():
    var owner = owner_player()
    if owner == null:
        return null
    var result = null
    for weapon in owner.current_weapons:
        if is_instance_valid(weapon) and (result == null or weapon.current_stats.damage > result.current_stats.damage):
            result = weapon
    return result if result != null else unarmed_fallback()

func unarmed_fallback():
    # This hidden source is never added to the player's inventory or allowed
    # to shoot. Its final tier-III stats feed the ordinary Incubus copy path.
    var data: WeaponData = load("res://mods-unpacked/Local-Isaac/content/weapons/tear/3/tear_3_data.tres")
    if not is_instance_valid(fallback_weapon):
        var container = Node2D.new()
        container.name = "FallbackSource"
        add_child(container)
        fallback_weapon = data.scene.instance()
        fallback_weapon.stats = data.stats.duplicate()
        fallback_weapon.weapon_id = data.weapon_id
        fallback_weapon.weapon_id_hash = data.get_weapon_id_hash()
        fallback_weapon.weapon_pos = -1
        fallback_weapon.weapon_sets = data.sets.duplicate()
        fallback_weapon.tier = data.tier
        # Weapon._ready() writes the outline material before computing stats.
        # Construct a concrete private ShaderMaterial rather than duplicating
        # an inherited scene export while the hidden source is being created.
        var outline = ShaderMaterial.new()
        outline.shader = load("res://resources/shaders/outline.gdshader")
        outline.set_shader_param("width", 2.0)
        fallback_weapon.outline_shader_mat = outline
        isolate_scene_resources(fallback_weapon)
        configure_fallback_scaling(data.stats)
        fallback_weapon.set_physics_process(false)
        fallback_weapon.set_process(false)
        fallback_weapon.hide()
        container.add_child(fallback_weapon)
        # Adding the child runs native Weapon/RangedWeapon _ready exactly once:
        # player index, hitbox, shooting behavior and final stats now exist.
        fallback_weapon.set_physics_process(false)
        fallback_weapon.set_process(false)
        fallback_weapon.disable_hitbox()
        fallback_weapon._range.set_deferred("monitoring", false)
    else:
        configure_fallback_scaling(data.stats)
        fallback_weapon.init_stats(false)
    return fallback_weapon

func configure_fallback_scaling(base_stats: WeaponStats) -> void:
    fallback_weapon.stats.scaling_stats = WeaponService._apply_beast_master_weapon_scaling_stat_effects(base_stats.scaling_stats.duplicate(true), player_index)

func should_data_be_reload() -> bool:
    return true

func reload_data() -> void:
    refresh_copy(false)

func get_stats() -> Array:
    return [copied_weapon.current_stats] if is_instance_valid(copied_weapon) else []

func set_current_stats(_values: Array) -> void:
    # Shared pet stat caches must not substitute a stale copy of another
    # player's current highest-damage weapon. Refresh directly from the owner.
    refresh_copy(false)

func refresh_copy(force: bool = false) -> void:
    if is_instance_valid(copied_weapon) and copied_weapon._is_shooting and not force:
        return
    var selected = highest_weapon()
    if selected == null:
        clear_copy()
        return
    if selected == source_weapon and is_instance_valid(copied_weapon):
        copied_weapon.init_stats(false)
        return
    clear_copy()
    source_weapon = selected
    var packed = load(selected.filename) if selected.filename != "" else null
    if packed == null:
        var data = RunData.get_player_weapons_ref(player_index)
        if selected.weapon_pos >= 0 and selected.weapon_pos < data.size():
            packed = data[selected.weapon_pos].scene
    if packed == null:
        return
    var weapon = packed.instance()
    # Keep the native scene (muzzle, hit shape, shooting behavior and art).
    # Only replace the root inventory bookkeeping and final-stat initialization.
    weapon.set_script(RANGED_COPY if selected.stats is RangedWeaponStats else MELEE_COPY)
    clean_scene_signals(weapon, weapon)
    isolate_scene_resources(weapon)
    weapon.source_weapon = selected
    weapon.curse_particles = selected.curse_particles
    weapon.custom_hit_sounds = selected.custom_hit_sounds.duplicate()
    weapon.outline_shader_mat = selected.outline_shader_mat.duplicate() if selected.outline_shader_mat != null else null
    weapon.stats = selected.stats.duplicate()
    weapon.weapon_id = selected.weapon_id
    weapon.weapon_id_hash = selected.weapon_id_hash
    weapon.weapon_pos = -1
    weapon.weapon_sets = selected.weapon_sets.duplicate()
    weapon.tier = selected.tier
    weapon.is_cursed = selected.is_cursed
    for effect in selected.effects:
        weapon.effects.append(effect.duplicate())
    $Weapons.add_child(weapon)
    copied_weapon = weapon
    copied_weapon.position = Vector2(0, -24)
    if copied_weapon.current_stats is RangedWeaponStats:
        copied_weapon._shooting_behavior._ranged_spawn_projectile_args.damage_tracking_key_hash = Keys.generate_hash("item_local_isaac_" + isaac_copy_kind)

func clean_scene_signals(node: Node, root: Node) -> void:
    # Railgun's owner-only charge timer, for example, is already reflected in
    # the copied live stats. It must not call methods removed with its script.
    for signal_info in node.get_signal_list():
        for connection in node.get_signal_connection_list(signal_info.name):
            if connection.target == root and not root.has_method(connection.method):
                node.disconnect(signal_info.name, root, connection.method)
    for child in node.get_children():
        clean_scene_signals(child, root)

func isolate_scene_resources(node: Node) -> void:
    # Native range circles are generally local-to-scene already, but not every
    # weapon scene (especially modded ones) marks them that way. The copy's
    # init_stats writes the detection radius, so always own shapes/materials.
    if node is CollisionShape2D and node.shape != null:
        node.shape = node.shape.duplicate()
    if node is CanvasItem and node.material != null:
        node.material = node.material.duplicate()
    for child in node.get_children():
        isolate_scene_resources(child)

func clear_copy() -> void:
    if is_instance_valid(copied_weapon):
        copied_weapon.set_physics_process(false)
        copied_weapon.tween.stop_all()
        copied_weapon.tween_animation.stop_all()
        copied_weapon.disable_hitbox()
        # Old projectiles still refer to their source. Keep an inert source
        # until wave cleanup rather than invalidating in-flight native effects.
        copied_weapon.hide()
        copied_weapon.set_process(false)
    copied_weapon = null
    source_weapon = null

func get_nb_weapons() -> int:
    var owner = owner_player()
    return owner.current_weapons.size() if owner != null else 1

func on_copy_attack(direction: float) -> void:
    shots_fired += 1
    last_projectiles = []
    motion.pulse(direction)

func update_orbit(delta: float) -> void:
    var owner = owner_player()
    if owner == null:
        return
    orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
    var phase = float(get_meta("isaac_gemini_phase")) if has_meta("isaac_gemini_phase") else 0.0
    var wanted = owner.global_position + Vector2(ORBIT_RADIUS, 0).rotated(orbit_angle + phase)
    global_position = Vector2(clamp(wanted.x, _min_pos.x, _max_pos.x), clamp(wanted.y, _min_pos.y, _max_pos.y))

func _physics_process(delta: float) -> void:
    if dead or _end_of_wave or not RunData.wave_in_progress:
        return
    update_orbit(delta)
    sync_left -= delta
    if sync_left <= 0.0:
        sync_left = 0.25
        refresh_copy()

func take_damage(_value: int, _args: TakeDamageArgs) -> Array:
    return [0, 0, false]

func end_of_wave_callback() -> void:
    .end_of_wave_callback()
    cleaning_up = true
    clear_copy()
