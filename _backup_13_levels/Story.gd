extends RefCounted
## Story.gd — the story told between levels. Each level has an "intro" (shown before it starts) and an
## "outro" (shown after the boss falls). StoryScene.gd plays them as small animated scenes.
##
## Part I   (levels 1-5)   Princess Zara is stolen; every time the hero finds her, someone else takes her.
## Part II  (levels 6-10)  The Shadow King curses her to sleep; four Moon Shards can break it.
## Part III (levels 11-13) The Abyss Emperor takes the shards and Zara; the Great Bell can wake her.
##
## Text may use {hero} (the player's name, filled in by StoryScene). The princess is never named.
## Scene fields: kind (raid, snatch, track, reunion, curse, shard, steal_all, face, bell),
## lines (the captions, one per beat), villain (colour of the enemy), plus optional chapter (title card),
## shards (how many Moon Shards the hero holds), asleep (Zara is sleeping), end (show "THE END").

## Set to false to replay every scene each time (useful while testing the story).
const SKIP_SEEN := true

const SCENES: Array[Dictionary] = [
	# ---------------------------------------------------------------- 1 THE DUNGEON
	{
		"intro": {"kind": "raid", "chapter": "PART I  -  THE STOLEN PRINCESS", "villain": Color(0.85, 0.25, 0.25),
			"lines": [
				"A quiet night in the royal castle...",
				"The Princess watches the stars from her window.",
				"Dark raiders slip out of the shadows... and take her.",
				"Her loyal guard {hero} rushes after them, but is too late.",
			]},
		"outro": {"kind": "snatch", "villain": Color(0.35, 0.85, 0.35),
			"lines": [
				"The Warden falls. The Princess is here, alive!",
				"\"{hero}! You came for me!\" she cries.",
				"But a second raider crashes through the wall...",
				"...and carries her away into the jungle.",
			]},
	},
	# ---------------------------------------------------------------- 2 THE JUNGLE RUINS
	{
		"intro": {"kind": "track", "villain": Color(0.4, 0.9, 0.4),
			"lines": [
				"The raiders' trail leads deep into the jungle.",
				"Every footprint glows faintly with dark magic.",
				"{hero} follows. Nothing will stop the search.",
			]},
		"outro": {"kind": "snatch", "villain": Color(0.95, 0.8, 0.35),
			"lines": [
				"The Spider Queen is defeated. The Princess's cell stands open!",
				"\"Run, {hero}! They are coming back!\" she calls.",
				"A scorpion rider swoops in from the dunes...",
				"...and the Princess is gone once again.",
			]},
	},
	# ---------------------------------------------------------------- 3 THE DESERT TOMB
	{
		"intro": {"kind": "track", "villain": Color(0.95, 0.8, 0.35),
			"lines": [
				"The desert wind erases the tracks, but not {hero}'s will.",
				"Beyond the dunes, a tomb of gold waits.",
			]},
		"outro": {"kind": "snatch", "villain": Color(1.0, 0.5, 0.2),
			"lines": [
				"The Scorpion King is beaten. The Princess is chained in his treasury!",
				"{hero} reaches for her... but fire bursts from the ground.",
				"A tyrant's great hand snatches her through the flames.",
			]},
	},
	# ---------------------------------------------------------------- 4 THE LAVA FORGE
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.5, 0.2),
			"lines": [
				"Rivers of lava light the road.",
				"Someone dragged the Princess this way. The heat is deadly.",
				"{hero} walks on.",
			]},
		"outro": {"kind": "snatch", "villain": Color(0.6, 0.85, 1.0),
			"lines": [
				"The Lava Golem crumbles into ash.",
				"The Princess cries out from her cage... then an icy wind howls.",
				"A frost wraith pulls her into the blizzard.",
			]},
	},
	# ---------------------------------------------------------------- 5 THE FROZEN KEEP
	{
		"intro": {"kind": "track", "villain": Color(0.6, 0.85, 1.0),
			"lines": [
				"Snow covers everything. The trail ends at the Frozen Keep.",
				"This is the last place left to look.",
			]},
		"outro": {"kind": "reunion", "villain": Color(0.7, 0.3, 0.9),
			"lines": [
				"The Frost Wraith shatters like glass.",
				"At last, the Princess is safe in {hero}'s arms.",
				"\"I knew you would never stop, {hero},\" she whispers.",
				"But far away, in a dark citadel, a king is watching...",
			]},
	},
	# ---------------------------------------------------------------- 6 THE SHADOW CITADEL
	{
		"intro": {"kind": "curse", "chapter": "PART II  -  THE SLEEPING CURSE", "villain": Color(0.7, 0.3, 0.9),
			"lines": [
				"The Shadow King was waiting for them.",
				"\"You took my prize. Now I take her light.\"",
				"A dark curse falls on the Princess. She sleeps, and will not wake.",
				"Only four Moon Shards can break the spell.",
			]},
		"outro": {"kind": "shard", "shards": 0, "villain": Color(0.7, 0.3, 0.9),
			"lines": [
				"The Shadow King falls... but the curse remains.",
				"The Moon Shards lie scattered across the old lands.",
				"{hero} lifts the Princess and sets out once more.",
			]},
	},
	# ---------------------------------------------------------------- 7 THE BONE CRYPT
	{
		"intro": {"kind": "track", "villain": Color(0.85, 0.88, 0.7),
			"lines": [
				"The first shard is said to rest in the Bone Crypt.",
				"Skeletons rattle in the dark. {hero} does not turn back.",
			]},
		"outro": {"kind": "shard", "shards": 1, "villain": Color(0.85, 0.88, 0.7),
			"lines": [
				"The Bone Lord crumbles. The first Moon Shard is {hero}'s!",
				"It glows softly. One of four.",
			]},
	},
	# ---------------------------------------------------------------- 8 THE HAUNTED MANOR
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.95, 1.0),
			"lines": [
				"Cold whispers drift through the old manor.",
				"The second shard hides among the ghosts.",
			]},
		"outro": {"kind": "shard", "shards": 2, "villain": Color(0.7, 0.95, 1.0),
			"lines": [
				"The Banshee's song fades into silence.",
				"The second Moon Shard shines in {hero}'s hand. Two of four.",
			]},
	},
	# ---------------------------------------------------------------- 9 THE SUNKEN TEMPLE
	{
		"intro": {"kind": "track", "villain": Color(0.4, 0.95, 0.85),
			"lines": [
				"Flooded halls, poison water, and watchful dead.",
				"The third shard lies at the bottom of the temple.",
			]},
		"outro": {"kind": "shard", "shards": 3, "villain": Color(0.4, 0.95, 0.85),
			"lines": [
				"The Drowned King sinks beneath the water.",
				"Three shards. Only one more to find.",
			]},
	},
	# ---------------------------------------------------------------- 10 THE CRIMSON CATHEDRAL
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.4, 0.45),
			"lines": [
				"The last shard is kept in the Crimson Cathedral.",
				"Red light streams through the broken windows.",
			]},
		"outro": {"kind": "steal_all", "villain": Color(0.55, 0.2, 0.9),
			"lines": [
				"The Blood Bishop falls. The fourth shard is in his hand!",
				"Four shards! The curse can finally be broken!",
				"But a huge shadow falls... the Abyss Emperor takes the shards, and the Princess.",
			]},
	},
	# ---------------------------------------------------------------- 11 THE STORM FORTRESS
	{
		"intro": {"kind": "face", "chapter": "PART III  -  THE FINAL BELL", "villain": Color(0.55, 0.2, 0.9),
			"lines": [
				"The Abyss Emperor wants the Princess's light to rule forever.",
				"His storm fortress guards the road to the Abyss.",
				"{hero} is alone, but not afraid.",
			]},
		"outro": {"kind": "track", "villain": Color(1.0, 0.95, 0.5),
			"lines": [
				"The Storm Warden falls. Lightning splits the sky.",
				"The road to the Abyss Throne is open.",
			]},
	},
	# ---------------------------------------------------------------- 12 THE ABYSS THRONE
	{
		"intro": {"kind": "face", "villain": Color(0.55, 0.2, 0.9),
			"lines": [
				"The Abyss Throne. The Emperor smiles from his seat.",
				"\"Give up, {hero}. She is mine.\"",
				"{hero} raises a sword.",
			]},
		"outro": {"kind": "reunion", "asleep": true, "villain": Color(0.55, 0.2, 0.9),
			"lines": [
				"The Abyss Emperor is defeated. The shards return to {hero}.",
				"But the Princess still sleeps.",
				"A voice whispers: \"Ring the Great Bell.\"",
			]},
	},
	# ---------------------------------------------------------------- 13 THE BELL TOWER
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.75, 0.35),
			"lines": [
				"The Great Bell hangs at the top of the Bell Tower.",
				"Its song can wake any sleeper, if it can be rung.",
			]},
		"outro": {"kind": "bell", "end": true, "villain": Color(1.0, 0.75, 0.35),
			"lines": [
				"The Bell Keeper falls. {hero} climbs to the Great Bell.",
				"Its golden voice rolls across the land.",
				"The Princess opens her eyes. The curse is broken.",
				"Together at last, they walk home as the sun rises.",
			]},
	},
]


## The scene to play for a level ("intro" or "outro"), or {} if there is none.
static func get_scene(level: int, which: String) -> Dictionary:
	if level < 0 or level >= SCENES.size():
		return {}
	return SCENES[level].get(which, {})
