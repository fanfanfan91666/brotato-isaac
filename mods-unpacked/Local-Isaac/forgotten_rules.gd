extends Reference

const CHARACTER_ID = "character_local_forgotten"
const BAR_PHASE = "isaac_forgotten_phase"
const PATH = "res://mods-unpacked/Local-Isaac/forgotten_rules.gd"

var player
var revived = false
var wave_number = -1
var wave_active = false
var applied_size = 1.0
var size_initialized = false
var animation_tracks = []
var bezier_tracks = []
var collision_data = []
var hurtbox_position = Vector2.ZERO

static func attach(owner_player):
    var p = int(owner_player.player_index)
    if p < 0 or p >= RunData.get_player_count():
        return null
    var character = RunData.get_player_character(p)
    if character == null or character.my_id != CHARACTER_ID:
        return null
    return load(PATH).new(owner_player)

func _init(owner_player = null) -> void:
    player = owner_player

static func body_size_percent(damage_percent: float, maximum_health: float) -> int:
    return int(floor(max(0.0, damage_percent) / 5.0)) + int(floor(max(0.0, maximum_health) / 5.0))

static func body_size_factor(damage_percent: float, maximum_health: float) -> float:
    return 1.0 + body_size_percent(damage_percent, maximum_health) / 100.0

func ensure_wave() -> bool:
    if not is_instance_valid(player) or player.dead:
        return false
    if not RunData.wave_in_progress:
        wave_active = false
        return false
    if not wave_active or wave_number != RunData.current_wave:
        wave_number = RunData.current_wave
        wave_active = true
        revived = false
    return true

func one_hit_active() -> bool:
    return ensure_wave() and revived

func bar_phase() -> int:
    ensure_wave()
    return 2 if revived else 1

func try_revive(args) -> bool:
    if args.cleaning_up or not ensure_wave() or revived or player.current_stats.health > 0:
        return false
    # Intercept before Entity.die marks death, disables collisions, or emits
    # died. Player.respawn is deliberately unavailable in the native game.
    revived = true
    player._pending_die = false
    player.current_stats.health = max(1, player.max_stats.health)
    player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)
    return true

func update_body_size() -> void:
    var factor = body_size_factor(Utils.get_stat(Keys.stat_percent_damage_hash, player.player_index), player.max_stats.health)
    player.isaac_body_size_factor = factor
    if is_equal_approx(factor, applied_size):
        return
    if not size_initialized:
        initialize_body_size()
    # Native move uses value tracks, while idle (including swim) writes the
    # same transform through Bezier tracks. Scale both from their originals
    # so changing animation cannot replace the persistent body-size factor.
    for row in animation_tracks:
        for key_index in row[2].size():
            row[0].track_set_key_value(row[1], key_index, row[2][key_index] * factor)
    for row in bezier_tracks:
        for key_index in row[2].size():
            var original = row[2][key_index]
            row[0].bezier_track_set_key_value(row[1], key_index, original[0] * factor)
            # Handles use (time, value) offsets: preserve animation timing and
            # scale only the value axis, including non-horizontal tangents.
            row[0].bezier_track_set_key_in_handle(row[1], key_index, original[1] * Vector2(1.0, factor))
            row[0].bezier_track_set_key_out_handle(row[1], key_index, original[2] * Vector2(1.0, factor))
    var ratio = factor / applied_size
    player._animation.scale *= ratio
    player._animation.position *= ratio
    for row in collision_data:
        row[0].position = row[1] * factor
        row[2].radius = row[3] * factor
    player._hurtbox.position = hurtbox_position * factor
    applied_size = factor

func initialize_body_size() -> void:
    size_initialized = true
    var animator = player._animation_player
    for animation_name in animator.get_animation_list():
        var animation = animator.get_animation(animation_name).duplicate()
        animator.add_animation(animation_name, animation)
        for track in animation.get_track_count():
            var path = String(animation.track_get_path(track))
            if not path in ["Animation:scale", "Animation:scale:x", "Animation:scale:y", "Animation:position", "Animation:position:x", "Animation:position:y"]:
                continue
            var track_type = animation.track_get_type(track)
            if track_type != Animation.TYPE_VALUE and track_type != Animation.TYPE_BEZIER:
                continue
            var original_values = []
            for key_index in animation.track_get_key_count(track):
                if track_type == Animation.TYPE_BEZIER:
                    original_values.append([animation.bezier_track_get_key_value(track, key_index), animation.bezier_track_get_key_in_handle(track, key_index), animation.bezier_track_get_key_out_handle(track, key_index)])
                else:
                    original_values.append(animation.track_get_key_value(track, key_index))
            if track_type == Animation.TYPE_BEZIER:
                bezier_tracks.append([animation, track, original_values])
            else:
                animation_tracks.append([animation, track, original_values])
    # Shapes belong to scene resources by default. Copy only this player's
    # two circles, then always derive their sizes from the original radius.
    for collision in [player._collision, player._hurtbox._collision]:
        var shape = collision.shape.duplicate()
        collision.shape = shape
        collision_data.append([collision, collision.position, shape, shape.radius])
    hurtbox_position = player._hurtbox.position
