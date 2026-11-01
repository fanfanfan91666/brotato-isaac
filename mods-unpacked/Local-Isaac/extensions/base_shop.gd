extends "res://ui/menus/shop/base_shop.gd"

const ISAAC_D6 = preload("res://mods-unpacked/Local-Isaac/isaac_rules.gd")

var isaac_room_buttons = {}
var isaac_room_overlay = null

func _ready() -> void:
    call_deferred("isaac_install_room_entry")

func isaac_install_room_entry() -> void:
    if isaac_room_overlay != null or load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").room_kind() == 0:
        return
    isaac_room_overlay = load("res://mods-unpacked/Local-Isaac/rooms/shop_overlay_034.gd").new()
    isaac_room_overlay.shop = self
    add_child(isaac_room_overlay)
    isaac_room_overlay.connect("room_closed", self, "_on_isaac_room_closed")
    for player_index in RunData.get_player_count():
        var reroll = _get_reroll_button(player_index)
        var button = Button.new()
        button.name = "IsaacRoomButton"
        button.text = tr(load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").title_key())
        var room_icon = "devil_entry" if load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").room_kind() == 1 else "angel_entry"
        button.icon = load("res://mods-unpacked/Local-Isaac/content/rooms/" + room_icon + ".png")
        button.expand_icon = true
        button.icon_align = Button.ALIGN_LEFT
        button.rect_min_size = Vector2(150 if RunData.is_coop_run else 220, 56)
        button.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
        button.set_script(load("res://ui/menus/global/my_menu_button.gd"))
        button.connect("pressed", self, "_on_isaac_room_pressed", [player_index])
        var row = reroll.get_parent()
        row.add_child(button)
        row.move_child(button, reroll.get_index() + 1)
        button.focus_neighbour_left = button.get_path_to(reroll)
        button.focus_neighbour_right = NodePath(".")
        for margin in [MARGIN_TOP, MARGIN_BOTTOM]:
            var original_path = reroll.get_focus_neighbour(margin)
            if not original_path.is_empty():
                var original = reroll.get_node_or_null(original_path)
                if original != null:
                    button.set_focus_neighbour(margin, button.get_path_to(original))
        reroll.focus_neighbour_right = reroll.get_path_to(button)
        isaac_room_buttons[player_index] = button

func _on_isaac_room_pressed(player_index: int) -> void:
    if isaac_room_overlay != null:
        isaac_room_overlay.open_room(player_index)

func _on_isaac_room_closed(player_index: int) -> void:
    call_deferred("isaac_restore_room_entry_focus", player_index)

func isaac_restore_room_entry_focus(player_index: int) -> void:
    if not is_inside_tree() or is_queued_for_deletion() or not isaac_room_buttons.has(player_index):
        return
    var button = isaac_room_buttons[player_index]
    if not is_instance_valid(button) or not button.is_inside_tree() or not button.is_visible_in_tree() or button.focus_mode == Control.FOCUS_NONE:
        return
    if RunData.is_coop_run:
        var emulator = Utils.get_focus_emulator(player_index, self)
        if emulator != null:
            emulator.focused_control = button
    else:
        button.grab_focus()

func isaac_save_room_state() -> void:
    ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)

func isaac_room_purchase_completed(player_index: int) -> void:
    _get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
    _update_stats(player_index)
    _get_shop_items_container(player_index).reload_shop_items()
    update_go_next_button_text()
    # Item effects may change a price/free quota, but visiting/purchasing a
    # room never invokes a reroll or consumes a D6 coupon.
    var result = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
    _reroll_price[player_index] = result[0]
    _reroll_discount[player_index] = result[1]
    var total_free_rerolls = RunData.get_player_effect(Keys.free_rerolls_hash, player_index)
    if total_free_rerolls > _initial_free_rerolls[player_index]:
        _free_rerolls[player_index] += total_free_rerolls - _initial_free_rerolls[player_index]
        _initial_free_rerolls[player_index] = total_free_rerolls
    set_reroll_button_price(player_index)

func _combine_weapon(weapon_data: WeaponData, player_index: int, is_upgrade: bool) -> void:
    if weapon_data.weapon_id != "weapon_local_isaac_wooden_nickel":
        ._combine_weapon(weapon_data, player_index, is_upgrade)
        return
    var previous = RunData.get_player_weapons_ref(player_index).duplicate()
    ._combine_weapon(weapon_data, player_index, is_upgrade)
    var current = RunData.get_player_weapons_ref(player_index)
    var progress = 0
    for old in previous:
        if old.weapon_id == weapon_data.weapon_id and not current.has(old):
            progress += old.isaac_coin_progress
    for result in current:
        if result.weapon_id == weapon_data.weapon_id and not previous.has(result):
            result.isaac_coin_progress = progress
            load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").settle_coin(result, player_index)
            break

func set_reroll_button_price(player_index: int) -> void:
    .set_reroll_button_price(player_index)
    if ISAAC_D6.coupons(player_index) > 0:
        _reroll_price[player_index] = 0
        _get_reroll_button(player_index).init(0, player_index)

func _on_RerollButton_pressed(player_index: int) -> void:
    if RunData.get_nb_item(Keys.generate_hash(ISAAC_D6.D6_ID), player_index) == 0 and ISAAC_D6.coupons(player_index) == 0:
        ._on_RerollButton_pressed(player_index)
        return
    var previous_count = _reroll_count[player_index]
    var use_coupon = ISAAC_D6.coupons(player_index) > 0 and _free_rerolls[player_index] == 0 and not _has_bonus_free_reroll[player_index]
    var bunny_tracking = RunData.tracked_item_effects[player_index].get(Keys.item_dangerous_bunny_hash, 0)
    # Let vanilla perform a genuinely free reroll without raising paid prices.
    # This temporary quota is consumed by vanilla and is never saved as a bunny.
    if use_coupon:
        _free_rerolls[player_index] += 1
    ._on_RerollButton_pressed(player_index)
    if _reroll_count[player_index] == previous_count:
        if use_coupon:
            _free_rerolls[player_index] -= 1
        return
    if use_coupon:
        RunData.set_tracked_value(player_index, Keys.item_dangerous_bunny_hash, bunny_tracking)
    ISAAC_D6.complete_reroll(player_index, use_coupon)
    var result = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
    _reroll_price[player_index] = result[0]
    _reroll_discount[player_index] = result[1]
    set_reroll_button_price(player_index)
    ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
