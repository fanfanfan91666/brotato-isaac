extends "res://ui/menus/shop/stats_container.gd"

const ISAAC_PRIMARY_ROWS_PER_PAGE = 16
const ISAAC_SECONDARY_ROWS_PER_PAGE = 19

var isaac_stat_pages = [[], []]
var isaac_page = 0
var isaac_stat_player = -1
var isaac_page_bar: HBoxContainer
var isaac_previous_page: TextureButton
var isaac_next_page: TextureButton
var isaac_page_label: Label

func _ready() -> void:
    var content = ItemService.isaac_content
    if content == null:
        return
    # The native ready method has already added the active DLC's own rows.
    isaac_stat_pages[Tab.PRIMARY] = isaac_split_stat_rows(primary_stats, ISAAC_PRIMARY_ROWS_PER_PAGE)
    isaac_stat_pages[Tab.SECONDARY] = isaac_split_stat_rows(secondary_stats, ISAAC_SECONDARY_ROWS_PER_PAGE)
    var isaac_rows = []
    for stat in content.stats:
        var row = load("res://ui/menus/shop/stat_container.tscn").instance()
        row.key = stat.stat_name.to_upper()
        _primary_stats.add_child(row)
        row.init_label_focus()
        row.enable_focus()
        row.connect("focused", self, "on_stat_focused")
        row.connect("unfocused", self, "on_stat_unfocused")
        row.connect("hovered", self, "on_stat_hovered")
        row.connect("unhovered", self, "on_stat_unhovered")
        isaac_rows.append(row)
    primary_stats.append_array(isaac_rows)
    var primary_pages = isaac_stat_pages[Tab.PRIMARY]
    if primary_pages.back().size() + isaac_rows.size() > ISAAC_PRIMARY_ROWS_PER_PAGE:
        primary_pages.append(isaac_rows)
    else:
        primary_pages.back().append_array(isaac_rows)

    isaac_page_bar = HBoxContainer.new()
    isaac_page_bar.alignment = BoxContainer.ALIGN_CENTER
    isaac_page_bar.add_constant_override("separation", 12)
    _primary_stats.get_parent().add_child(isaac_page_bar)
    isaac_previous_page = isaac_make_page_arrow("arrow_left_border.png", -1)
    isaac_page_label = Label.new()
    isaac_page_bar.add_child(isaac_page_label)
    isaac_next_page = isaac_make_page_arrow("arrow_right_border.png", 1)
    isaac_show_page()
    set_process_input(is_visible_in_tree())

func isaac_split_stat_rows(rows: Array, page_size: int) -> Array:
    var pages = []
    for start in range(0, rows.size(), page_size):
        pages.append(rows.slice(start, start + page_size - 1))
    return pages

func isaac_make_page_arrow(image_name: String, direction: int) -> TextureButton:
    var arrow = TextureButton.new()
    arrow.texture_normal = load("res://ui/menus/global/" + image_name)
    arrow.texture_focused = arrow.texture_normal
    arrow.rect_min_size = Vector2(40, 28)
    arrow.expand = true
    arrow.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    arrow.connect("pressed", self, "isaac_step_page", [direction])
    isaac_page_bar.add_child(arrow)
    return arrow

func update_player_stats(player_index: int) -> void:
    isaac_stat_player = player_index
    .update_player_stats(player_index)

func update_tab(tab: int) -> void:
    isaac_page = 0
    .update_tab(tab)
    if isaac_page_bar != null:
        isaac_show_page()

func _input(event: InputEvent) -> void:
    if isaac_page_bar == null:
        ._input(event)
        return
    if not is_visible_in_tree():
        return

    var direction = 0
    if show_buttons and event is InputEventJoypadButton:
        if event.is_action_pressed("ltrigger"):
            direction = -1
        elif event.is_action_pressed("rtrigger"):
            direction = 1
    elif not show_buttons and isaac_stat_player >= 0 and RunData.is_coop_run and event is InputEventJoypadMotion:
        # Coop triggers already control the outer equipment/primary/secondary carousel.
        if Utils.is_player_action_pressed(event, isaac_stat_player, "rjoy_left"):
            direction = -1
        elif Utils.is_player_action_pressed(event, isaac_stat_player, "rjoy_right"):
            direction = 1
    if direction != 0:
        isaac_step_page(direction)

func isaac_step_page(direction: int) -> void:
    var focused = get_focus_owner()
    var focus_emulator = null
    if RunData.is_coop_run and isaac_stat_player >= 0:
        focus_emulator = Utils.get_focus_emulator(isaac_stat_player)
        focused = focus_emulator.focused_control if focus_emulator != null else null

    var next_page = isaac_page + direction
    if next_page < 0 or next_page >= isaac_stat_pages[focused_tab].size():
        if not show_buttons:
            return
        update_tab(Tab.SECONDARY if focused_tab == Tab.PRIMARY else Tab.PRIMARY)
        next_page = isaac_stat_pages[focused_tab].size() - 1 if direction < 0 else 0
    isaac_page = next_page
    isaac_show_page()

    if RunData.is_coop_run and focus_emulator == null:
        return
    if focused in primary_stats and not focused.is_visible_in_tree():
        var next_focus = first_primary_stat if focused_tab == Tab.PRIMARY else _secondary_tab
        Utils.focus_player_control(next_focus, isaac_stat_player, focus_emulator)
    elif focused == isaac_previous_page and isaac_previous_page.disabled:
        Utils.focus_player_control(isaac_next_page, isaac_stat_player, focus_emulator)
    elif focused == isaac_next_page and isaac_next_page.disabled:
        Utils.focus_player_control(isaac_previous_page, isaac_stat_player, focus_emulator)

func isaac_show_page() -> void:
    var pages = isaac_stat_pages[focused_tab]
    var page = pages[isaac_page]
    var rows = primary_stats if focused_tab == Tab.PRIMARY else secondary_stats
    for row in rows:
        row.visible = row in page
    if focused_tab == Tab.PRIMARY:
        first_primary_stat = page.front()
        last_primary_stat = page.back()
    set_focus_neighbours()

    isaac_page_bar.visible = pages.size() > 1
    isaac_page_label.text = "%d / %d" % [isaac_page + 1, pages.size()]
    isaac_previous_page.disabled = isaac_page == 0
    isaac_next_page.disabled = isaac_page == pages.size() - 1
    isaac_previous_page.modulate.a = 0.3 if isaac_previous_page.disabled else 1.0
    isaac_next_page.modulate.a = 0.3 if isaac_next_page.disabled else 1.0
