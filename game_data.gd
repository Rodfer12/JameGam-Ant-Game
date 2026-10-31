class_name GameData
extends RefCounted

## All tunable content lives here: ants, upgrades, enemies, bosses and floors.
## Add a new entry to any table and the rest of the game picks it up.

# Room types (must match AnthillGenerator.RoomType).
const ROOM_START := 0
const ROOM_COMBAT := 1
const ROOM_ELITE := 2
const ROOM_TREASURE := 3
const ROOM_REST := 4
const ROOM_BOSS := 5

const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "EPIC"]
const RARITY_COLORS: Array[String] = ["#b9d9a8", "#7cc8ff", "#ffb84d"]

const AFFIXES: Array[String] = ["SWIFT", "ARMORED", "EXPLOSIVE", "SPLITTING"]

# ---------------------------------------------------------------------------
# Playable ants. Numbers are additive modifiers applied in GameState.
# ---------------------------------------------------------------------------
const ANTS: Array[Dictionary] = [
	{"name": "BROWN", "title": "WORKER", "column": 0, "amber": 0.2,
		"desc": "A tireless forager. Finds more amber.",
		"perks": ["+20% AMBER FOUND"]},
	{"name": "RED", "title": "SOLDIER", "column": 3, "bite": 2.0, "hp": -1,
		"desc": "Built for close combat. Hits hard, bleeds easily.",
		"perks": ["+2 BITE DAMAGE", "-1 MAX HEALTH"]},
	{"name": "GREEN", "title": "SPITTER", "column": 6, "spit": 1.0, "poison": 0.3, "bite": -1.0,
		"desc": "A walking venom gland. Weak in melee.",
		"perks": ["+1 SPIT DAMAGE", "+30% POISON TIME", "-1 BITE DAMAGE"]},
	{"name": "GREY", "title": "GUARD", "column": 9, "armor": 2, "hp": 1, "speed": -0.1,
		"desc": "Thick plating and a slow, steady march.",
		"perks": ["+2 SHIELD", "+1 MAX HEALTH", "-10% SPEED"]}
]

# ---------------------------------------------------------------------------
# In-run upgrades. rarity: 0 common, 1 rare, 2 epic.
# ---------------------------------------------------------------------------
const UPGRADES: Array[Dictionary] = [
	{"id": "gland", "name": "TOXIC GLAND", "desc": "+1 spit damage", "rarity": 0, "max": 8, "glyph": "drop"},
	{"id": "legs", "name": "LIGHT LEGS", "desc": "+10% move speed", "rarity": 0, "max": 5, "glyph": "boot"},
	{"id": "carapace", "name": "THICK CARAPACE", "desc": "+2 max health and heal 2", "rarity": 0, "max": 6, "glyph": "heart"},
	{"id": "fangs", "name": "RAPID FANGS", "desc": "Spit recharges 12% faster", "rarity": 0, "max": 5, "glyph": "clock"},
	{"id": "venom", "name": "LINGERING VENOM", "desc": "Poison lasts 0.8s longer", "rarity": 0, "max": 5, "glyph": "flask"},
	{"id": "mandibles", "name": "SHARP MANDIBLES", "desc": "+2 bite damage", "rarity": 0, "max": 6, "glyph": "bite"},
	{"id": "lunge", "name": "SWIFT LUNGE", "desc": "Dash recharges 15% faster", "rarity": 0, "max": 4, "glyph": "dash"},
	{"id": "eyes", "name": "KEEN EYES", "desc": "+6% critical hit chance", "rarity": 0, "max": 5, "glyph": "eye"},
	{"id": "plates", "name": "CHITIN PLATES", "desc": "+2 shield, refills every room", "rarity": 0, "max": 5, "glyph": "shield"},
	{"id": "magnet", "name": "HONEY MAGNET", "desc": "Wider pickup range, +15% amber", "rarity": 0, "max": 3, "glyph": "magnet"},
	{"id": "jelly", "name": "ROYAL JELLY", "desc": "Restore all health", "rarity": 0, "max": 99, "instant": true, "glyph": "heart"},
	{"id": "twin", "name": "TWIN SPIT", "desc": "Fire +1 spit projectile", "rarity": 1, "max": 2, "glyph": "multi"},
	{"id": "pierce", "name": "PIERCING FANGS", "desc": "Spit pierces +1 enemy", "rarity": 1, "max": 3, "glyph": "pierce"},
	{"id": "virulent", "name": "VIRULENT STRAIN", "desc": "Poison stacks higher and hits harder", "rarity": 1, "max": 3, "glyph": "virus"},
	{"id": "vampiric", "name": "VAMPIRIC BITE", "desc": "Bite kills have +35% chance to heal 1", "rarity": 1, "max": 3, "glyph": "drain"},
	{"id": "trail", "name": "ACID TRAIL", "desc": "Dashing leaves burning venom", "rarity": 1, "max": 3, "glyph": "trail"},
	{"id": "thorns", "name": "THORNY HIDE", "desc": "Attackers take damage and stagger", "rarity": 1, "max": 3, "glyph": "thorn"},
	{"id": "deflector", "name": "DEFLECTOR", "desc": "Bite reflects enemy projectiles", "rarity": 1, "max": 1, "glyph": "deflect"},
	{"id": "double", "name": "DOUBLE DASH", "desc": "+1 dash charge", "rarity": 1, "max": 2, "glyph": "double"},
	{"id": "ricochet", "name": "RICOCHET SPIT", "desc": "Spit bounces off walls once more", "rarity": 1, "max": 2, "glyph": "bounce"},
	{"id": "adrenaline", "name": "ADRENALINE", "desc": "+1% damage per combo (max 15)", "rarity": 1, "max": 3, "glyph": "combo"},
	{"id": "plague", "name": "PLAGUE BEARER", "desc": "Poisoned foes spread poison on death", "rarity": 2, "max": 2, "glyph": "plague"},
	{"id": "rage", "name": "BERSERKER SCENT", "desc": "Below half health: +40% damage and speed", "rarity": 2, "max": 1, "glyph": "rage"},
	{"id": "exec", "name": "EXECUTIONER", "desc": "Bites slay foes under 25% (then 40%) health", "rarity": 2, "max": 2, "glyph": "skull"},
	{"id": "boom", "name": "CAUSTIC BLOOM", "desc": "Foes killed by poison explode", "rarity": 2, "max": 2, "glyph": "burst"},
	{"id": "wind", "name": "SECOND WIND", "desc": "Survive a killing blow once per run", "rarity": 2, "max": 1, "glyph": "wings"}
]

# ---------------------------------------------------------------------------
# Permanent upgrades bought with amber in the Colony Hall.
# Cost of the next level = cost * (current level + 1).
# ---------------------------------------------------------------------------
const META: Array[Dictionary] = [
	{"id": "hp", "name": "FORTIFIED BURROW", "desc": "+1 max health", "max": 5, "cost": 30, "glyph": "heart"},
	{"id": "venom", "name": "POTENT VENOM", "desc": "+1 spit damage", "max": 4, "cost": 45, "glyph": "drop"},
	{"id": "speed", "name": "QUICK SCUTTLE", "desc": "+4% move speed", "max": 5, "cost": 25, "glyph": "boot"},
	{"id": "nose", "name": "AMBER NOSE", "desc": "+10% amber found", "max": 5, "cost": 35, "glyph": "amber"},
	{"id": "pack", "name": "FORAGER'S PACK", "desc": "Start each run with a free upgrade", "max": 3, "cost": 60, "glyph": "plus"},
	{"id": "favor", "name": "ROYAL FAVOR", "desc": "Better upgrade rarity", "max": 3, "cost": 55, "glyph": "star"},
	{"id": "wind", "name": "BROOD MEMORY", "desc": "Survive one killing blow each run", "max": 1, "cost": 250, "glyph": "wings"}
]

# ---------------------------------------------------------------------------
# Regular enemies.
#  ai: chase | charger | ranged | orbit | bomber | tank | summoner
#  col: column in Bugs.png (3 frames per bug species, so 0 / 3 / 6 / 9).
# ---------------------------------------------------------------------------
const ENEMIES := {
	"grub": {"name": "LARVA", "hp": 4.0, "speed": 66.0, "radius": 8.0, "damage": 1, "cost": 1.0, "weight": 4.0,
		"min_floor": 1, "ai": "chase", "col": 0, "tint": "#ffffff", "scale": 0.85, "amber": 1, "points": 10,
		"cooldown": [1.0, 2.0]},
	"beetle": {"name": "BEETLE", "hp": 10.0, "speed": 50.0, "radius": 10.0, "damage": 1, "cost": 3.0, "weight": 3.0,
		"min_floor": 1, "ai": "charger", "col": 9, "tint": "#ffffff", "scale": 1.0, "amber": 2, "points": 30,
		"cooldown": [2.0, 3.2]},
	"spitter": {"name": "SPITTER", "hp": 7.0, "speed": 44.0, "radius": 9.0, "damage": 1, "cost": 3.0, "weight": 2.5,
		"min_floor": 2, "ai": "ranged", "col": 3, "tint": "#b8ffb0", "scale": 1.0, "amber": 2, "points": 35,
		"cooldown": [1.6, 2.4]},
	"bomber": {"name": "BOMBARDIER", "hp": 5.0, "speed": 82.0, "radius": 9.0, "damage": 2, "cost": 3.0, "weight": 2.0,
		"min_floor": 2, "ai": "bomber", "col": 6, "tint": "#ffd0a0", "scale": 0.95, "amber": 2, "points": 30,
		"contact": false, "cooldown": [0.5, 0.8]},
	"wasp": {"name": "WASP", "hp": 6.0, "speed": 88.0, "radius": 9.0, "damage": 1, "cost": 3.0, "weight": 2.0,
		"min_floor": 3, "ai": "orbit", "col": 3, "tint": "#ffe27a", "scale": 0.95, "amber": 2, "points": 35,
		"cooldown": [1.4, 2.2]},
	"tank": {"name": "WEEVIL", "hp": 30.0, "speed": 34.0, "radius": 13.0, "damage": 2, "cost": 6.0, "weight": 1.5,
		"min_floor": 3, "ai": "tank", "col": 9, "tint": "#a9b4c9", "scale": 1.3, "amber": 4, "points": 80,
		"slam_radius": 54.0, "cooldown": [1.8, 2.8]},
	"summoner": {"name": "BROODKEEPER", "hp": 14.0, "speed": 40.0, "radius": 10.0, "damage": 1, "cost": 5.0, "weight": 1.2,
		"min_floor": 4, "ai": "summoner", "col": 3, "tint": "#d9a8ff", "scale": 1.05, "amber": 4, "points": 70,
		"cooldown": [5.5, 7.0]}
}

# ---------------------------------------------------------------------------
# Bosses: one per floor. Each phase lists the attacks the boss may use.
# Attacks: charge, slam, ring, fan, summon, blink, puddles, slash.
# ---------------------------------------------------------------------------
const BOSSES := {
	"warden": {"name": "BEETLE WARDEN", "title": "GUARDIAN OF THE ROOTS", "hp": 110.0, "speed": 44.0, "radius": 15.0,
		"damage": 1, "col": 9, "tint": "#d6c6ff", "scale": 1.0, "minion": "grub", "charges": 0, "amber": 18, "points": 400,
		"phases": [["charge", "slam"], ["charge", "slam", "summon"], ["charge", "slam", "ring"]]},
	"mother": {"name": "SPORE MOTHER", "title": "QUEEN OF THE GARDEN", "hp": 150.0, "speed": 38.0, "radius": 15.0,
		"damage": 1, "col": 6, "tint": "#a8ffcf", "scale": 1.0, "minion": "bomber", "charges": 0, "amber": 22, "points": 600,
		"phases": [["ring", "puddles"], ["ring", "puddles", "summon"], ["fan", "ring", "puddles", "summon"]]},
	"matron": {"name": "NURSE MATRON", "title": "MOTHER OF THE BROOD", "hp": 190.0, "speed": 42.0, "radius": 15.0,
		"damage": 1, "col": 3, "tint": "#e0b0ff", "scale": 1.0, "minion": "grub", "charges": 0, "amber": 26, "points": 800,
		"phases": [["fan", "summon"], ["fan", "summon", "ring"], ["fan", "ring", "summon", "slam"]]},
	"mantis": {"name": "CRYSTAL MANTIS", "title": "THE SHARDED BLADE", "hp": 230.0, "speed": 52.0, "radius": 15.0,
		"damage": 2, "col": 6, "tint": "#9fd0ff", "scale": 1.0, "minion": "wasp", "charges": 1, "amber": 30, "points": 1000,
		"phases": [["slash", "blink"], ["slash", "fan", "blink"], ["slash", "blink", "ring", "fan"]]},
	"hornet": {"name": "HORNET CAPTAIN", "title": "WARLORD OF THE WARRENS", "hp": 270.0, "speed": 58.0, "radius": 15.0,
		"damage": 2, "col": 3, "tint": "#ff9a8a", "scale": 1.0, "minion": "wasp", "charges": 2, "amber": 34, "points": 1300,
		"phases": [["charge", "fan"], ["charge", "fan", "blink"], ["charge", "blink", "ring", "summon"]]},
	"queen": {"name": "THE QUEEN", "title": "SOVEREIGN OF THE COLONY", "hp": 420.0, "speed": 46.0, "radius": 17.0,
		"damage": 2, "col": 9, "tint": "#ff8fd0", "scale": 1.1, "minion": "beetle", "charges": 1, "amber": 60, "points": 3000,
		"phases": [["fan", "summon", "slam"], ["ring", "charge", "summon", "puddles"], ["fan", "ring", "blink", "slam", "charge", "summon"]]}
}

# ---------------------------------------------------------------------------
# Floors. themes index CaveTileset.THEME_NAMES. sides lists optional dead-end rooms.
# ---------------------------------------------------------------------------
const FLOORS: Array[Dictionary] = [
	{"name": "THE ROOTBOUND TUNNELS", "subtitle": "Where the garden roots tangle the dark",
		"themes": [0], "rooms": 5, "sides": [3], "elites": 0, "boss": "warden", "ambient": "#706b85"},
	{"name": "THE FUNGUS GARDENS", "subtitle": "Damp, glowing, and full of spores",
		"themes": [1], "rooms": 6, "sides": [3, 4], "elites": 1, "boss": "mother", "ambient": "#6a8a86"},
	{"name": "THE NURSERY", "subtitle": "Soft silk. Hungry larvae.",
		"themes": [2, 3], "rooms": 6, "sides": [3, 4], "elites": 1, "boss": "matron", "ambient": "#7d6c9a"},
	{"name": "THE CRYSTAL DEPTHS", "subtitle": "Light bends strangely this far down",
		"themes": [5], "rooms": 7, "sides": [3, 4], "elites": 2, "boss": "mantis", "ambient": "#5f78a8"},
	{"name": "THE SCARLET WARRENS", "subtitle": "The enemy colony's war camp",
		"themes": [4], "rooms": 7, "sides": [3, 4], "elites": 2, "boss": "hornet", "ambient": "#94606c"},
	{"name": "THE QUEEN'S COURT", "subtitle": "The end of the tunnels",
		"themes": [6, 4], "rooms": 6, "sides": [4], "elites": 2, "boss": "queen", "ambient": "#92608c"}
]

const ROOM_NAMES: Array = [
	["ROOT CELLAR", "GNARLED HOLLOW", "MOLE RUN", "WORM WALK", "TANGLED CHAMBER", "THE LOW DEN"],
	["SPORE GARDEN", "MUSHROOM GROVE", "DAMP HOLLOW", "CAP CHAMBER", "THE MYCELIUM", "GLOWCAP CAVERN"],
	["BROOD CHAMBER", "EGG VAULT", "LARVA CRECHE", "SILKEN HALL", "THE HATCHERY", "NURSE'S REST"],
	["DRY NEST", "STRAW HALL", "THE GRANARY", "WARM CHAMBER", "THE LOFT", "CHAFF PIT"],
	["BLOOD TUNNEL", "SCARLET HALL", "THE EMBER DEN", "RED GALLERY", "THE WARBAND CAMP", "CRIMSON PIT"],
	["PRISM CAVERN", "GEODE HALL", "SHARD GALLERY", "THE LUMINARY", "FROSTED VAULT", "RESONANT CAVE"],
	["ROYAL ANTECHAMBER", "GUARD HALL", "THRONE APPROACH", "JELLY VAULT", "THE ARMORY", "THE SILK COURT"]
]

const ROOM_FLAVOR: Array[String] = [
	"Roots creak overhead...",
	"Spores drift lazily through the air.",
	"Something skitters in the silk.",
	"Warm, dry, and far too quiet.",
	"The walls are stained dark red.",
	"Crystals hum a low, sour note.",
	"The air smells of royal jelly."
]
