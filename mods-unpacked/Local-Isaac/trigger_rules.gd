extends Reference

static func probability(base: float, per_luck: float, luck: float, copies: int = 1) -> float:
    return clamp(copies * (base + luck * per_luck), 0.0, 1.0)

# The caller owns this dictionary per player or weapon and supplies game time.
# One attack_key represents one volley, regardless of its projectile count.
static func advance(state: Dictionary, config: Dictionary, attack_key: String, game_seconds: float, luck: float = 0.0, copies: int = 1) -> bool:
    if copies <= 0:
        state.clear()
        return false
    if state.get("last_attack", "") == attack_key:
        return false
    state.last_attack = attack_key
    var counting = config.get("mode", "chance") == "count"
    var every = max(1, int(config.get("every", 1)))
    if counting:
        state.progress = min(every, int(state.get("progress", 0)) + 1)
        if state.progress < every:
            return false
    if game_seconds < float(state.get("next_allowed", 0.0)):
        return false
    if not counting and Utils._rng.randf() >= probability(float(config.get("chance", 0.01)), float(config.get("per_luck", 0.0)), luck, copies):
        return false
    state.progress = 0
    state.next_allowed = game_seconds + max(0.0, float(config.get("cooldown", 0.0)))
    return true
