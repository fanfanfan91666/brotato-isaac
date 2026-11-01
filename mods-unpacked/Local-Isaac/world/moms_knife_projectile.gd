extends "res://projectiles/player_projectile.gd"

func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    # Keep the native projectile/pool logic but never spend penetration or damage.
    _hitbox.ignored_objects.append(thing_hit)
    emit_signal("hit_something", thing_hit, damage_dealt)
