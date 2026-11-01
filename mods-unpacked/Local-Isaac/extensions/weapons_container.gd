extends "res://entities/units/player/weapons_container.gd"

const ISAAC_RING_WEAPONS = ["weapon_local_isaac_tear", "weapon_local_isaac_wooden_nickel"]
const ISAAC_RING_RADIUS = 26.0

func update_weapons_positions(weapons: Array) -> void:
    .update_weapons_positions(weapons)
    # Preserve the native body-center offset and all ordinary attachments.
    for i in weapons.size():
        if weapons[i].weapon_id in ISAAC_RING_WEAPONS:
            var angle = i * 2.0 * PI / weapons.size()
            weapons[i].attach(Vector2(ISAAC_RING_RADIUS, 0).rotated(angle), 0)
