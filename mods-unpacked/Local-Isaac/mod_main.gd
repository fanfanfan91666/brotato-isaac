extends Node

# Keep helpers alive only after Mod Loader installs all base extensions.
# Loading native-class dependencies while extensions are being parsed can
# capture incompatible copies of nested argument types.
var isaac_helper_cache = []
var isaac_head_setup

func _ready() -> void:
    call_deferred("isaac_hold_helpers")

func isaac_hold_helpers() -> void:
    if not isaac_helper_cache.empty():
        return
    for path in ["isaac_rules.gd", "bomb_rules.gd", "stat_rules.gd", "attack_rules.gd", "baby_rules.gd", "lilith_rules.gd", "zodiac_rules.gd", "zodiac_balance.gd", "curse_rules.gd", "description_rules.gd", "new_items_019.gd", "poison_rules.gd", "world/attack_utility.gd", "world/poison.gd", "world/ipecac_burn.gd", "world/aquarius_wave.gd", "world/slow_melee_motion.gd", "world/slow_melee_stats.gd", "world/incubus_weapon_rules.gd", "world/eyeshadow_charm.tscn"]:
        isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/" + path))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/head_visuals.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/weapon_art.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/pickaxe_rules_030.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/world/bomb_pickup.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/world/petrify_031.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/world/fear_041.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/scenery_rules_032.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd"))
    for path in ["world/data_hack_attack_033.gd", "world/data_hack_dot_033.gd", "world/data_hack_projectile_033.gd"]:
        isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/" + path))
    for path in ["special_rooms_034.gd", "rooms/shop_overlay_034.gd", "rooms/shop_card_034.gd"]:
        isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/" + path))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/rib_size_rules_037.gd"))
    isaac_helper_cache.append(load("res://mods-unpacked/Local-Isaac/forgotten_rules.gd"))
    call_deferred("isaac_setup_head_visuals")

func isaac_setup_head_visuals() -> void:
    isaac_head_setup = load("res://mods-unpacked/Local-Isaac/head_visuals.gd").install(self)
    if isaac_head_setup is GDScriptFunctionState:
        yield(isaac_head_setup, "completed")
    isaac_head_setup = null

func _init() -> void:
    var extensions = ModLoaderMod.get_unpacked_dir().plus_file("Local-Isaac/extensions")
    ModLoaderMod.install_script_extension(extensions.plus_file("weapon_selection.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("base_shop.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("player.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("ui_progress_bar.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("player_ui_elements.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("weapons_container.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("character_panel_ui.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("run_data.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("entity_spawner.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("main.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("consumable.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("item_service.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("stat_container.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("weapon.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("utils.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("weapon_service.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("ranged_shooting.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("melee_shooting.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("unit.gd"))
    ModLoaderMod.install_script_extension(extensions.plus_file("enemy.gd"))
