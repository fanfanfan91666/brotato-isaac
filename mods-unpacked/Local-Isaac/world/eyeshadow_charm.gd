extends "res://dlcs/dlc_1/effect_behaviors/enemy/charm_enemy_effect_behavior.gd"

func on_hurt(_hitbox: Hitbox) -> void:
    # The equipped weapon already rolled once for this attack/volley.
    pass

func charm(from_player_index: int) -> void:
    if charmed:
        return
    var native_speed_boost = _parent.current_stats.speed > 0
    .charm(from_player_index)
    # Native charm only restores on death. Do not borrow bonus_speed while
    # alive: charging enemies can replace that field during the eight seconds.
    if native_speed_boost:
        _parent.bonus_speed -= 100
    load("res://mods-unpacked/Local-Isaac/poison_rules.gd").clear(_parent)
    load("res://mods-unpacked/Local-Isaac/data_hack_rules_033.gd").clear_status(_parent)
    var custom_fire = _parent.get_node_or_null("IsaacBabyBurn")
    if custom_fire != null:
        custom_fire.finish()

func _on_CharmTimer_timeout() -> void:
    if is_instance_valid(_parent) and not _parent.dead:
        uncharm()

func uncharm() -> void:
    if not charmed:
        return
    if _parent.current_stats.speed > 0:
        _parent.bonus_speed += 100
    .uncharm()
    charmed = false
    _absorb_next_damage = false
    _charm_timer.stop()
    if is_instance_valid(_parent):
        _parent.remove_outline(Utils.CHARM_COLOR)
        _parent.reset_damage_stat()
        _parent._hurtbox.enable()
        _parent._entity_spawner_ref.charmed_enemies.erase(_parent)
        _parent._entity_spawner_ref._all_enemy_dirty = true
        _parent.update_target()

func _exit_tree() -> void:
    if charmed and is_instance_valid(_parent):
        uncharm()
