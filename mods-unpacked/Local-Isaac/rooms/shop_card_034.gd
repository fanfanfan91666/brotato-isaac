extends "res://ui/menus/shop/shop_item.gd"

var _isaac_buy_presses = []
var room_kind = 0

func _ready() -> void:
    # Native BuyButton dispatch is deferred. Capture ownership synchronously,
    # before this shared card can be reused by another player's room.
    _button.connect("pressed", self, "_isaac_capture_buy_press")
    get_node("TopButtonsContainer").hide()
    get_node("BottomButtonsContainer").hide()

func _isaac_capture_buy_press() -> void:
    _isaac_buy_presses.append([player_index, item_data.my_id_hash if item_data != null else 0])

func _on_BuyButton_pressed() -> void:
    if _isaac_buy_presses.empty():
        return
    var captured = _isaac_buy_presses.pop_front()
    if not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or not active or item_data == null:
        return
    if int(captured[0]) != player_index or int(captured[1]) != item_data.my_id_hash:
        return
    ._on_BuyButton_pressed()

# Keep the original shop card, description, tier panel and purchase button.
# Only this room's payment display changes; ordinary shop cards stay native.
func set_shop_item(data: ItemParentData, wave: int = RunData.current_wave) -> void:
    .set_shop_item(data, wave)
    var rules = load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd")
    room_kind = rules.room_kind()
    value = rules.price_for(data, player_index)
    _button.remove_additional_icon()
    _button.gold_icon.show()
    if rules.currency_for(player_index) == "hp":
        _button.set_material_icon(ItemService.get_stat_icon(Keys.stat_max_hp_hash))
        _button.set_value(value, rules.currency_amount(player_index))
    else:
        _button.set_material_icon(load("res://items/materials/material_ui.png"), Utils.GOLD_COLOR)
        _button.set_value(value, RunData.get_player_gold(player_index))
    get_node("TopButtonsContainer").hide()
    get_node("BottomButtonsContainer").hide()
    disable_lock_focus()

func set_room_offer(offer: Dictionary) -> void:
    set_shop_item(offer.item, RunData.current_wave)

func update_color() -> void:
    _button.set_color_from_currency(load("res://mods-unpacked/Local-Isaac/special_rooms_034.gd").currency_amount(player_index))

func change_lock_status(_pressed: bool) -> void:
    pass

func steal_item() -> void:
    pass

func ban_item() -> void:
    pass
