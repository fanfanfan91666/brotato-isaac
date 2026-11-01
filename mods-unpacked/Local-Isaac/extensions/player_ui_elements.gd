extends "res://ui/hud/player_ui_elements.gd"

func update_life_label(player: Player) -> void:
    var phase = int(player.life_bar_effects().get("isaac_forgotten_phase", 0))
    if phase == 2:
        isaac_clear_life_label()
        return
    .update_life_label(player)
    if phase == 1:
        # Native update_life_label changes text only; a new wave must unhide it.
        life_label.show()

func hide_life_label(player: Player) -> void:
    if int(player.life_bar_effects().get("isaac_forgotten_phase", 0)) == 2:
        isaac_clear_life_label()
        return
    .hide_life_label(player)

func isaac_clear_life_label() -> void:
    # Native hide_life_label only hides the Label and leaves its old HP text.
    life_label.text = ""
    life_label.hide()
