extends "res://ui/menus/shop/base_shop.gd"

var isaac_room_buttons = {}
var isaac_room_overlay = null

func _ready() -> void:
    call_deferred("isaac_install_room_entry")
    call_deferred("isaac_resume_forget_me_now")

func isaac_resume_forget_me_now() -> void:
    if load("res://mods-unpacked/Local-Isaac/resurrection_rules_0412.gd").request_rewind(self):
        isaac_save_room_state()

func isaac_install_room_entry() -> void:
    if isaac_room_overlay != null or load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").room_kind() == 0:
        return
    isaac_room_overlay = load("res://mods-unpacked/Local-Isaac/rooms/shop_overlay_034.gd").new()
    isaac_room_overlay.shop = self
    add_child(isaac_room_overlay)
    isaac_room_overlay.connect("room_closed", self, "_on_isaac_room_closed")
    for player_index in RunData.get_player_count():
        var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
        for kind in rules.kinds_for(player_index):
            isaac_add_room_entry(player_index, kind)
    isaac_refresh_room_entries()

func isaac_add_room_entry(player_index: int, kind: int) -> void:
    if not load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").room_available(player_index, kind):
        return
    var reroll = _get_reroll_button(player_index)
    var button = Button.new()
    button.name = "IsaacRoomButton"
    button.text = tr(load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").title_key(-1, kind))
    var room_icon = "devil_entry" if kind == 1 else "angel_entry"
    button.icon = load("res://mods-unpacked/Local-Isaac/content/rooms/" + room_icon + ".png")
    button.expand_icon = true
    button.icon_align = Button.ALIGN_LEFT
    button.rect_min_size = Vector2(150 if RunData.is_coop_run else 220, 56)
    button.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
    button.set_script(load("res://ui/menus/global/my_menu_button.gd"))
    button.connect("pressed", self, "_on_isaac_room_pressed", [player_index, kind])
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
    isaac_room_buttons[player_index * 2 + kind - 1] = button

func _on_isaac_room_pressed(player_index: int, kind: int) -> void:
    if isaac_room_overlay != null and load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").room_available(player_index, kind):
        isaac_room_overlay.open_room(player_index, kind)
        isaac_refresh_room_entries()

func _on_isaac_room_closed(player_index: int) -> void:
    call_deferred("isaac_restore_room_entry_focus", player_index)

func isaac_refresh_room_entries() -> void:
    var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    for key in isaac_room_buttons:
        isaac_room_buttons[key].visible = rules.room_available(int(key / 2), key % 2 + 1)
    for player in RunData.get_player_count():
        var buttons = []
        for kind in [1, 2]:
            var key = player * 2 + kind - 1
            if isaac_room_buttons.has(key) and isaac_room_buttons[key].visible:
                buttons.append(isaac_room_buttons[key])
        var reroll = _get_reroll_button(player)
        for index in buttons.size():
            var left = reroll if index == 0 else buttons[index - 1]
            var right = buttons[index + 1] if index + 1 < buttons.size() else buttons[index]
            buttons[index].focus_neighbour_left = buttons[index].get_path_to(left)
            buttons[index].focus_neighbour_right = buttons[index].get_path_to(right)
        if not buttons.empty():
            reroll.focus_neighbour_right = reroll.get_path_to(buttons[0])

func isaac_restore_room_entry_focus(player_index: int) -> void:
    if not is_inside_tree() or is_queued_for_deletion():
        return
    isaac_refresh_room_entries()
    var chosen = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").selected_kind(player_index)
    var key = player_index * 2 + chosen - 1
    if not isaac_room_buttons.has(key):
        return
    var button = isaac_room_buttons[key]
    if not is_instance_valid(button) or not button.is_visible_in_tree():
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
    _refresh_bonus_free_reroll(player_index)
    isaac_resume_forget_me_now()

func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void:
    .on_shop_item_bought(shop_item, player_index)
    isaac_resume_forget_me_now()

func set_reroll_button_price(player_index: int) -> void:
    .set_reroll_button_price(player_index)
    if load("res://mods-unpacked/Local-Isaac/isaac_rules.gd").coupons(player_index) > 0:
        _reroll_price[player_index] = 0
        _get_reroll_button(player_index).init(0, player_index)

func _on_RerollButton_pressed(player_index: int) -> void:
    var d6 = load("res://mods-unpacked/Local-Isaac/isaac_rules.gd")
    if RunData.get_nb_item(Keys.generate_hash(d6.D6_ID), player_index) == 0 and d6.coupons(player_index) == 0:
        ._on_RerollButton_pressed(player_index)
        return
    var previous_count = _reroll_count[player_index]
    var use_coupon = d6.coupons(player_index) > 0 and _free_rerolls[player_index] == 0 and not _has_bonus_free_reroll[player_index]
    # Use the native one-shot bonus path so D6 cannot increase Bunny savings
    # or paid reroll counts. Native free rerolls take priority over coupons.
    if use_coupon:
        _has_bonus_free_reroll[player_index] = true
    ._on_RerollButton_pressed(player_index)
    if _reroll_count[player_index] == previous_count:
        if use_coupon:
            _has_bonus_free_reroll[player_index] = false
        return
    d6.complete_reroll(player_index, use_coupon)
    var result = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
    _reroll_price[player_index] = result[0]
    _reroll_discount[player_index] = result[1]
    set_reroll_button_price(player_index)
    isaac_save_room_state()
