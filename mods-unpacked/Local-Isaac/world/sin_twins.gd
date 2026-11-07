extends "res://mods-unpacked/Local-Isaac/world/incubus.gd"

const FIRST_BODY = preload("res://mods-unpacked/Local-Isaac/content/items/sin_twins/first.png")
const SECOND_BODY = preload("res://mods-unpacked/Local-Isaac/content/items/sin_twins/second.png")

func _init() -> void:
    isaac_copy_kind = "sin_twins"
    isaac_damage_factor = 0.4
    isaac_winged = false

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    var ordinal = 0
    var game = Utils.get_scene_node()
    for pet in game._entity_spawner.pets:
        if pet == self:
            break
        if pet.player_index == player_index and pet.get("isaac_copy_kind") == "sin_twins":
            ordinal += 1
    $Animation/Sprite.texture = FIRST_BODY if ordinal % 2 == 0 else SECOND_BODY
    orbit_angle = -PI / 2.0 + PI * (ordinal % 2)
    update_orbit(0.0)

func update_orbit(delta: float) -> void:
    var player = owner_player()
    if player == null:
        return
    orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
    var phase = float(get_meta("isaac_gemini_phase")) if has_meta("isaac_gemini_phase") else 0.0
    global_position = player.global_position + Vector2(170, 0).rotated(orbit_angle + phase)
