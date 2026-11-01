extends Control

signal room_closed(player)

var shop: Control
var active_player = -1
var cards = []
var slots = []
var statues = []
var _empty_slot_spacers = []
var back_button: Button
var gold_label: Label
var currency_icon: TextureRect
var title_label: Label
var hint_label: Label
var _content: Control
var _normal_content_visible = true
var _shop_input_enabled = true
var _focus_emulators = []
var _focus_emulator_inputs = []
var _focus_before = []
var _input_id = -1

func _ready() -> void:
    name = "IsaacSpecialRoom"
    anchor_right = 1.0
    anchor_bottom = 1.0
    theme = load("res://resources/themes/base_theme.tres")
    mouse_filter = Control.MOUSE_FILTER_STOP
    var background = TextureRect.new()
    background.name = "RoomBackground"
    background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background
    background.expand = true
    background.anchor_right = 1.0
    background.anchor_bottom = 1.0
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var margin = MarginContainer.new()
    margin.anchor_right = 1.0
    margin.anchor_bottom = 1.0
    for side in ["left", "right", "top", "bottom"]:
        margin.add_constant_override("margin_" + side, 35)
    add_child(margin)
    _content = VBoxContainer.new()
    _content.add_constant_override("separation", 30)
    margin.add_child(_content)
    var heading = HBoxContainer.new()
    _content.add_child(heading)
    title_label = Label.new()
    title_label.add_font_override("font", load("res://resources/fonts/actual/base/font_40_outline_thick.tres"))
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title_label)
    currency_icon = load("res://ui/menus/run/gold_icon.tscn").instance()
    currency_icon.name = "RoomCurrencyIcon"
    heading.add_child(currency_icon)
    gold_label = Label.new()
    gold_label.add_font_override("font", load("res://resources/fonts/actual/base/font_60_outline.tres"))
    heading.add_child(gold_label)
    hint_label = Label.new()
    hint_label.name = "RoomPaymentHint"
    hint_label.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
    _content.add_child(hint_label)
    hint_label.hide()
    var goods = HBoxContainer.new()
    goods.name = "RoomItems"
    goods.add_constant_override("separation", 20)
    goods.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _content.add_child(goods)
    var card_scene = load("res://mods-unpacked/Local-Isaac/rooms/shop_card_034.tscn")
    for slot in 4:
        # Keep all four physical columns even when this room rolls two or
        # three offers. Statues remain directly below columns one and four.
        var column = VBoxContainer.new()
        column.name = "RoomSlot" + str(slot + 1)
        column.rect_min_size.x = 300
        column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        column.add_constant_override("separation", 18)
        goods.add_child(column)
        slots.append(column)
        var card = card_scene.instance()
        card.name = "RoomShopItem" + str(slot + 1)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        # Native minimum panel height is retained; the four columns fill the
        # same 1920-wide shop canvas used by the original solo shop.
        card.rect_min_size.x = 300
        column.add_child(card)
        card.connect("buy_button_pressed", self, "_on_buy_pressed", [slot])
        cards.append(card)
        var empty_offer = Control.new()
        empty_offer.name = "EmptyOfferSpacer"
        empty_offer.rect_min_size.y = 475
        empty_offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        column.add_child(empty_offer)
        empty_offer.hide()
        _empty_slot_spacers.append(empty_offer)
        if slot == 0 or slot == 3:
            var statue = TextureRect.new()
            statue.name = "LeftRoomStatue" if slot == 0 else "RightRoomStatue"
            statue.rect_min_size = Vector2(220, 220)
            statue.expand = true
            statue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            statue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            statue.mouse_filter = Control.MOUSE_FILTER_IGNORE
            column.add_child(statue)
            statues.append(statue)
    back_button = Button.new()
    back_button.name = "ReturnShopButton"
    back_button.text = tr("LOCAL_ISAAC_RETURN_SHOP")
    back_button.rect_min_size = Vector2(350, 70)
    back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    back_button.set_script(load("res://ui/menus/global/my_menu_button.gd"))
    back_button.connect("pressed", self, "close_room")
    _content.add_child(back_button)
    RunData.connect("gold_changed", self, "_on_gold_changed")
    hide()

func is_room_open() -> bool:
    return is_inside_tree() and not is_queued_for_deletion() and visible and active_player >= 0

func open_room(player: int) -> void:
    if is_room_open() or shop == null or get_tree().paused:
        return
    var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    if rules.room_kind() == 0 or player < 0 or player >= RunData.get_player_count():
        return
    active_player = player
    rules.ensure_inventory(player, shop.get_player_shop_items(player))
    # Save generation immediately. Closing the menu without buying cannot
    # replace these offers on the next launch.
    shop.isaac_save_room_state()
    _normal_content_visible = shop.get_node("Content").visible
    _shop_input_enabled = shop.is_processing_input()
    _focus_emulators.clear()
    _focus_emulator_inputs.clear()
    _focus_before.clear()
    for p in RunData.get_player_count():
        var emulator = Utils.get_focus_emulator(p, shop)
        if emulator != null:
            _focus_emulators.append(emulator)
            _focus_emulator_inputs.append(emulator.is_processing_input())
            _focus_before.append(emulator.focused_control)
            emulator.set_process_input(false)
    shop.set_process_input(false)
    shop.get_node("Content").hide()
    title_label.text = tr(rules.title_key()) + " (" + Text.text("WAVE", [str(RunData.current_wave)]) + ")"
    if RunData.is_coop_run:
        title_label.text += "  P" + str(player + 1)
    show()
    get_parent().move_child(self, get_parent().get_child_count() - 1)
    _refresh_cards()
    call_deferred("_focus_first")

func close_room() -> void:
    if not is_room_open():
        return
    var player = active_player
    shop.isaac_save_room_state()
    hide()
    active_player = -1
    shop.get_node("Content").visible = _normal_content_visible
    shop.set_process_input(_shop_input_enabled)
    for i in _focus_emulators.size():
        var emulator = _focus_emulators[i]
        if is_instance_valid(emulator):
            emulator.set_process_input(_focus_emulator_inputs[i])
            if is_instance_valid(_focus_before[i]) and _focus_before[i].is_inside_tree() and not _focus_before[i].is_queued_for_deletion():
                emulator.focused_control = _focus_before[i]
    emit_signal("room_closed", player)

func _refresh_cards() -> void:
    var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    var offers = rules.get_offers(active_player)
    var statue_name = "devil_statue" if rules.room_kind() == 1 else "angel_statue"
    for statue in statues:
        statue.texture = load("res://mods-unpacked/Local-Isaac/content/rooms/" + statue_name + ".png")
    for card in cards:
        card.active = false
        card._button.disable()
        card.hide()
    for spacer in _empty_slot_spacers:
        spacer.show()
    for offer in offers:
        var card = cards[offer.slot]
        card.player_index = active_player
        if offer.item == null or offer.sold:
            continue
        card.show()
        _empty_slot_spacers[offer.slot].hide()
        card.set_room_offer(offer)
        card.active = offer.available
        if card.active:
            card._button.activate()
        else:
            card._button.disable()
        card.modulate.a = 0.45 if not offer.available else 1.0
        if offer.blocked:
            card._button.set_text("0")
        elif not offer.available:
            card._button.set_text(tr("LOCAL_ISAAC_SOLD_OUT"))
    _refresh_currency()
    var focusables = _focusable_buttons()
    for i in focusables.size():
        var button = focusables[i]
        button.focus_neighbour_left = button.get_path_to(focusables[(i - 1 + focusables.size()) % focusables.size()])
        button.focus_neighbour_right = button.get_path_to(focusables[(i + 1) % focusables.size()])
        button.focus_neighbour_top = button.get_path_to(back_button)
        button.focus_neighbour_bottom = button.get_path_to(back_button)

func _refresh_currency() -> void:
    var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    currency_icon.show()
    if rules.currency_for(active_player) == "hp":
        currency_icon.set_icon(ItemService.get_stat_icon(Keys.stat_max_hp_hash))
        gold_label.text = str(rules.currency_amount(active_player))
    else:
        currency_icon.set_icon(load("res://items/materials/material_ui.png"), Utils.GOLD_COLOR)
        gold_label.text = str(RunData.get_player_gold(active_player))

func _focusable_buttons() -> Array:
    var buttons = []
    for card in cards:
        if card.visible and card.active and not card._button.disabled:
            buttons.append(card._button)
    buttons.append(back_button)
    return buttons

func _focus_first() -> void:
    if not is_room_open():
        return
    var button = _focusable_buttons()[0]
    if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE and not button.disabled:
        button.grab_focus()

func _on_buy_pressed(_card: ShopItem, slot: int) -> void:
    if not is_room_open():
        return
    var result = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").purchase(active_player, slot)
    if not result.ok:
        UIService._reached_max_shake(gold_label.get_parent())
        return
    shop.isaac_room_purchase_completed(active_player)
    shop.isaac_save_room_state()
    _refresh_cards()
    call_deferred("_focus_first")

func _on_gold_changed(_value: int, player: int) -> void:
    if not is_room_open() or player != active_player:
        return
    _refresh_currency()
    for card in cards:
        if card.visible:
            card.update_color()

func _input(event: InputEvent) -> void:
    if not is_room_open() or event.get_instance_id() == _input_id:
        return
    _input_id = event.get_instance_id()
    if Utils.is_player_cancel_pressed(event, active_player):
        close_room()
        get_tree().set_input_as_handled()
        return
    if Utils.is_player_pause_released(event, active_player):
        var player = active_player
        close_room()
        shop._pause_menu.pause(player)
        get_tree().set_input_as_handled()
        return
    var buttons = _focusable_buttons()
    var index = buttons.find(get_focus_owner())
    if Utils.is_player_action_pressed(event, active_player, "ui_accept"):
        if index >= 0:
            buttons[index].emit_signal("pressed")
        get_tree().set_input_as_handled()
        return
    var step = 0
    if Utils.is_player_action_pressed(event, active_player, "ui_left") or Utils.is_player_action_pressed(event, active_player, "ui_up"):
        step = -1
    elif Utils.is_player_action_pressed(event, active_player, "ui_right") or Utils.is_player_action_pressed(event, active_player, "ui_down"):
        step = 1
    if step != 0:
        buttons[(index + step + buttons.size()) % buttons.size()].grab_focus()
        get_tree().set_input_as_handled()
        return
    # The shared fullscreen room belongs to the player who entered it. Other
    # controllers cannot spend that player's materials through GUI actions.
    if RunData.is_coop_run and not (event is InputEventMouse):
        for player in RunData.get_player_count():
            for action in ["ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "ui_select", "ui_ban", "ltrigger", "rtrigger"]:
                if Utils.is_player_action_pressed(event, player, action):
                    get_tree().set_input_as_handled()
                    return
