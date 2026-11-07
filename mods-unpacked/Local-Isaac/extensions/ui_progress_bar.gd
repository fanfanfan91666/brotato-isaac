extends "res://ui/hud/ui_progress_bar.gd"

const ISAAC_FORGOTTEN_GRAY = Color(0.60, 0.60, 0.60, 1.0)
const ISAAC_FORGOTTEN_RED = Color(0.85, 0.18, 0.18, 1.0)
const ISAAC_BARRIER_GOLD = Color(1.0, 0.78, 0.12, 1.0)

onready var _isaac_life_label = get_node_or_null("MarginContainer/LifeLabel")

func update_color_from_effects(effects: Dictionary) -> void:
    .update_color_from_effects(effects)
    var phase = int(effects.get("isaac_forgotten_phase", 0))
    var shadow_ready = bool(effects.get("isaac_judas_shadow_ready", false))
    var protection_ready = bool(effects.get("isaac_divine_barrier_ready", false)) or bool(effects.get("isaac_taurus_invulnerable", false))
    if phase <= 0 and not shadow_ready and not protection_ready:
        return
    if protection_ready:
        _non_flash_color = ISAAC_BARRIER_GOLD
    elif phase > 0 or shadow_ready:
        _non_flash_color = ISAAC_FORGOTTEN_GRAY if shadow_ready or phase == 1 else ISAAC_FORGOTTEN_RED
    if protection_ready or _flash_timer.time_left == 0:
        tint_progress = _non_flash_color
    # Main also writes health through native PlayerUIElements references.
    # Enforce the label state on the actual HUD bar, whose effect update is
    # called every physics frame. Character/XP bars have no LifeLabel.
    if _isaac_life_label != null:
        if phase == 2 or bool(effects.get("isaac_native_one_hit", false)):
            if _isaac_life_label.text != "":
                _isaac_life_label.text = ""
            if _isaac_life_label.visible:
                _isaac_life_label.hide()
        elif not _isaac_life_label.visible:
            _isaac_life_label.show()
