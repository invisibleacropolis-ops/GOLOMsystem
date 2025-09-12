extends Resource
class_name MapProfiles

## Preset terrain profiles used by `ProceduralMapGenerator`.
## Each profile specifies noise frequencies and thresholds that
## shape the resulting map.  Outside engineers can add or tweak
## profiles here to control high level world variety.
const PROFILES: Array[Dictionary] = [
    {
        "id": "plains",
        "elev_freq": 0.05,
        "grass_freq": 0.2,
        "tree_freq": 0.3,
        "water_threshold": -0.3,
        "dirt_threshold": 0.0,
        "hill_threshold": 0.4,
        "tree_threshold": 0.6,
    },
    {
        "id": "islands",
        "elev_freq": 0.08,
        "grass_freq": 0.25,
        "tree_freq": 0.35,
        "water_threshold": -0.2,
        "dirt_threshold": 0.2,
        "hill_threshold": 0.6,
        "tree_threshold": 0.65,
    },
    {
        "id": "mountains",
        "elev_freq": 0.03,
        "grass_freq": 0.15,
        "tree_freq": 0.25,
        "water_threshold": -0.4,
        "dirt_threshold": -0.1,
        "hill_threshold": 0.2,
        "tree_threshold": 0.7,
    },
]

## Returns the profile with a matching id or an empty dictionary if missing.
static func get_profile(id: String) -> Dictionary:
    for p in PROFILES:
        if p.get("id", "") == id:
            return p
    return {}

## Picks a deterministic profile using a seed string.
static func pick_profile(seed: String) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(seed)
    return PROFILES[rng.randi_range(0, PROFILES.size() - 1)]
