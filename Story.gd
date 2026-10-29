extends RefCounted
## Story.gd — the story told between levels: "The Dawn Crystal". Each of the 40 levels has an "intro"
## (shown before it starts) and an "outro" (shown after its boss falls). StoryScene.gd plays them as short
## animated scenes.
##
## The Night King shattered the Dawn Crystal (it keeps the sun rising) into 8 shards, hid them in 8 worlds
## and took the Princess to his Night Citadel. {hero} (the player's name) travels through all 8 worlds,
## one Dawn Shard per world, and at the end of level 40 the sun rises again.
##
## Text may use {hero} (the player's name, filled in by StoryScene). The princess is never named.
## Scene fields: kind, lines (the captions, one per beat), villain (colour of the enemy), plus optional
## chapter (title card), shards (Dawn Shards found, 1-8), end (show "THE END").
## Kinds: raid, track, face, victory, vision, shardget, sunrise (older ones: snatch, reunion, curse, shard, steal_all, bell).

## Set to false to replay every scene each time (useful while testing the story).
const SKIP_SEEN := true

const SCENES: Array[Dictionary] = [
	# ---- level 1
	{
		"intro": {"kind": "raid", "villain": Color(1.0, 0.5, 0.25), "chapter": "PART I  -  THE NIGHT OF FIRE",
			"lines": [
				"The Dawn Crystal keeps the sun rising. The Princess guards it.",
				"One dark night, the Night King's raiders storm the castle.",
				"They shatter the Crystal and carry the Princess into the dark.",
				"Her loyal guard {hero} fights to the gate, but the raiders are gone.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The Cinder Captain falls. A shard of the Crystal glitters in the ash.",
				"Only a spark... but it points east, toward the burning market.",
			]},
	},
	# ---- level 2
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The market streets are on fire.",
				"Imps dart between the burning stalls.",
				"{hero} follows the glowing spark.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The Ash Widow is defeated. Her lair holds a torn black banner.",
				"It is the Night King's mark. He took the Princess himself.",
			]},
	},
	# ---- level 3
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The old chapel still smolders.",
				"A whisper in the ash: \"She is not here... she is far away.\"",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The Torchbearer drops his flame. The spark grows brighter.",
				"The raiders' road leads to the Ember Keep.",
			]},
	},
	# ---- level 4
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"Hounds pick up the scent of smoke and fear.",
				"The granary is full of hungry eyes. {hero} sneaks through.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The Charred Knight crumbles. His key opens the way.",
				"The last fortress of Emberfall stands ahead.",
			]},
	},
	# ---- level 5
	{
		"intro": {"kind": "face", "villain": Color(1.0, 0.5, 0.25),
			"lines": [
				"The Ember King blocks the last gate of the keep.",
				"\"The Princess belongs to the Night!\" he roars.",
				"{hero} draws a sword.",
			]},
		"outro": {"kind": "shardget", "villain": Color(1.0, 0.5, 0.25), "shards": 1,
			"lines": [
				"The Ember King falls. The first Dawn Shard glows in {hero}'s hand.",
				"One of eight.",
				"The light shows a road south, into a foggy swamp.",
			]},
	},
	# ---- level 6
	{
		"intro": {"kind": "vision", "villain": Color(0.45, 0.9, 0.5), "chapter": "PART II  -  THE WHISPERING MIRE",
			"lines": [
				"A faint light rises from the shard: the Princess, far away.",
				"\"{hero}... I am in the Night Citadel. Find all eight shards.\"",
				"\"Only the Dawn Crystal can set me free.\"",
				"The vision fades. The swamp waits.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"The Bog Witch's curse breaks. The frogs croak in relief.",
				"The path deeper into the swamp opens.",
			]},
	},
	# ---- level 7
	{
		"intro": {"kind": "track", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"Giant mushrooms glow along the trail.",
				"Sleepy slimes drift in the fog. Strike quietly.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"The Spore Mother falls. The mushrooms stop glowing.",
				"Her last word is a name: the Night King.",
			]},
	},
	# ---- level 8
	{
		"intro": {"kind": "face", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"A drowned chapel. Listeners hear everything here.",
				"Sneak with C, or they will find you.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"The Leech Lord sinks into the mud.",
				"The witch's hut is not far now.",
			]},
	},
	# ---- level 9
	{
		"intro": {"kind": "track", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"Poison pools bubble across the swamp.",
				"{hero} jumps from stone to stone.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"The Muddy Deacon's chant is silenced.",
				"Only the witch's hut remains.",
			]},
	},
	# ---- level 10
	{
		"intro": {"kind": "face", "villain": Color(0.45, 0.9, 0.5),
			"lines": [
				"The Mire Tyrant rises from the water.",
				"\"Turn back, little guard. The shard is mine.\"",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.45, 0.9, 0.5), "shards": 2,
			"lines": [
				"The Mire Tyrant sinks for good. The second Dawn Shard rises from the mud.",
				"Two of eight.",
				"The shard hums and points down into the earth.",
			]},
	},
	# ---- level 11
	{
		"intro": {"kind": "track", "villain": Color(0.75, 0.55, 1.0), "chapter": "PART III  -  THE CRYSTAL DEEP",
			"lines": [
				"A tunnel of glowing crystals leads under the mountain.",
				"The crystals hum with a familiar light.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Gem Cutter drops his tools.",
				"Deeper in, the humming grows louder.",
			]},
	},
	# ---- level 12
	{
		"intro": {"kind": "track", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"Geodes as big as houses. Many guards sleep here.",
				"{hero} steps softly.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Shard Spider falls. Her web holds a torn diary page.",
				"\"The Night King is cold, but he still guards something warm.\"",
			]},
	},
	# ---- level 13
	{
		"intro": {"kind": "face", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"Light bends through the prisms. Scouts watch the long halls.",
				"Stay out of their narrow sight.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Geode Golem shatters into sparkling dust.",
				"An echo, very close: the Princess whispers, \"Keep going.\"",
			]},
	},
	# ---- level 14
	{
		"intro": {"kind": "track", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Echo Mine: every footstep rings.",
				"Listeners guard the tunnels. Quietly, {hero}.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Prism Warden's light goes out.",
				"The Heart Crystal is just ahead.",
			]},
	},
	# ---- level 15
	{
		"intro": {"kind": "face", "villain": Color(0.75, 0.55, 1.0),
			"lines": [
				"The Crystal Queen sits on a throne of living gems.",
				"\"Another thief. Another shard for my collection.\"",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.75, 0.55, 1.0), "shards": 3,
			"lines": [
				"The Crystal Queen cracks and falls. The third Dawn Shard is free.",
				"Three of eight.",
				"Far above, a great clock begins to chime.",
			]},
	},
	# ---- level 16
	{
		"intro": {"kind": "track", "villain": Color(0.95, 0.75, 0.35), "chapter": "PART IV  -  THE CLOCKWORK CITADEL",
			"lines": [
				"A city of gears rises from the mist.",
				"Every sentry marches on a schedule. Learn it, {hero}.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Tinkerer's machine winds down.",
				"The streets of the Citadel open.",
			]},
	},
	# ---- level 17
	{
		"intro": {"kind": "face", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"Steam tunnels and hot pipes. Spike plates click underfoot.",
				"The Cog Knight blocks the way.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Cog Knight falls with a clatter.",
				"A brass speaker crackles: the Night King's Herald is watching.",
			]},
	},
	# ---- level 18
	{
		"intro": {"kind": "track", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Great Forge never sleeps.",
				"Brutes hammer. Scouts watch every corner.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Steam Baron is silenced and the forge goes cold.",
				"In the dark, someone applauds, slowly.",
			]},
	},
	# ---- level 19
	{
		"intro": {"kind": "track", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"Giant pendulums swing across the halls.",
				"Time your steps, {hero}. One slip and the blades come down.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Great Pendulum stops.",
				"The Clock Tower waits above.",
			]},
	},
	# ---- level 20
	{
		"intro": {"kind": "face", "villain": Color(0.95, 0.75, 0.35),
			"lines": [
				"The Clockwork Emperor's gears turn without end.",
				"\"Time belongs to the Night King. So do you.\"",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.95, 0.75, 0.35), "shards": 4,
			"lines": [
				"The Emperor's gears grind to a halt. The fourth Dawn Shard clicks into place.",
				"Half of the Crystal is whole.",
				"The Herald vanishes. The road leads into the sea.",
			]},
	},
	# ---- level 21
	{
		"intro": {"kind": "track", "villain": Color(0.4, 0.85, 0.95), "chapter": "PART V  -  THE CORAL ABYSS",
			"lines": [
				"The sea floor. A fleet of wrecked ships.",
				"Bubbles rise from the dark. Something big moves below.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"The Tide Caller's song fades.",
				"The pearl gardens shimmer ahead.",
			]},
	},
	# ---- level 22
	{
		"intro": {"kind": "track", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"Coral gardens and pearl-eyed crabs.",
				"Every cove could hide an ambush.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"The Pearl Diver gives up his pearl lantern.",
				"It lights the way into the drowned galleon.",
			]},
	},
	# ---- level 23
	{
		"intro": {"kind": "face", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"A drowned galleon full of restless dead.",
				"Blinders throw glowing orbs. Keep moving.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"The Kraken's Hand slips back into the deep.",
				"The den is close. The water grows cold.",
			]},
	},
	# ---- level 24
	{
		"intro": {"kind": "track", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"Tentacles and teeth. Listeners guard the den.",
				"Quietly, {hero}.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"The Drowned Admiral sinks with his ship.",
				"The Leviathan stirs below.",
			]},
	},
	# ---- level 25
	{
		"intro": {"kind": "face", "villain": Color(0.4, 0.85, 0.95),
			"lines": [
				"The Leviathan opens one huge eye.",
				"A shard glows inside its heart.",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.4, 0.85, 0.95), "shards": 5,
			"lines": [
				"The Leviathan sinks. The fifth Dawn Shard floats up, shining.",
				"Five of eight.",
				"Snow begins to fall from a distant sky.",
			]},
	},
	# ---- level 26
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.9, 1.0), "chapter": "PART VI  -  THE FROZEN PEAKS",
			"lines": [
				"A howling mountain pass. The wind bites.",
				"Hounds follow {hero} by scent. Stay out of their sight.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The Snow Stalker collapses in a drift.",
				"The yeti caves lie ahead.",
			]},
	},
	# ---- level 27
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"Shaggy yetis fill the caves.",
				"They are huge, but slow.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The Ice Hermit lowers his staff. \"The Night King was once a guardian.\"",
				"\"He failed to protect the Crystal. Now he wants to own the dark.\"",
			]},
	},
	# ---- level 28
	{
		"intro": {"kind": "face", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The frozen lake cracks underfoot.",
				"Archers watch from the shore.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The Avalanche is stopped before it starts.",
				"The ridge path opens.",
			]},
	},
	# ---- level 29
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"One loud noise could bury the mountain.",
				"Scouts patrol the ridge. {hero} climbs quietly.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The Frost Wyrm falls.",
				"Only the Winter Throne remains.",
			]},
	},
	# ---- level 30
	{
		"intro": {"kind": "face", "villain": Color(0.7, 0.9, 1.0),
			"lines": [
				"The Winter Queen waits on a throne of ice.",
				"\"The Princess is mine to keep cold.\"",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.7, 0.9, 1.0), "shards": 6,
			"lines": [
				"The Winter Queen melts into snow. The sixth Dawn Shard burns bright.",
				"Six of eight.",
				"Gold glitters on the horizon: the Gilded Palace.",
			]},
	},
	# ---- level 31
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.85, 0.4), "chapter": "PART VII  -  THE GILDED PALACE",
			"lines": [
				"A palace of gold, ruled by a tyrant.",
				"Shieldbearers line the gates. Strike from the sides.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"The Court Jester's last joke falls flat.",
				"The masquerade begins.",
			]},
	},
	# ---- level 32
	{
		"intro": {"kind": "face", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"A masked ball of guards.",
				"Archers watch from the balconies.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"The Gilded Guard drops his golden spear.",
				"The library doors swing open.",
			]},
	},
	# ---- level 33
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"Marble shelves and silent halls.",
				"Blinders flash in the dark corners.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"The Crown Minister's ledger burns. It listed every shard's hiding place.",
				"Only one shard remains, and it is in the Night Citadel.",
			]},
	},
	# ---- level 34
	{
		"intro": {"kind": "track", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"Portraits with moving eyes.",
				"Scouts see everything. Hide behind the curtains.",
			]},
		"outro": {"kind": "victory", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"The Masked Duke's mask cracks. Beneath it there is only shadow.",
				"The throne room is next.",
			]},
	},
	# ---- level 35
	{
		"intro": {"kind": "face", "villain": Color(1.0, 0.85, 0.4),
			"lines": [
				"The Golden Tyrant offers {hero} a crown.",
				"\"Join me, and the Princess can stay forever.\"",
				"{hero} says no.",
			]},
		"outro": {"kind": "shardget", "villain": Color(1.0, 0.85, 0.4), "shards": 7,
			"lines": [
				"The Golden Tyrant's crown rolls across the floor. The seventh Dawn Shard is free.",
				"Seven of eight.",
				"Ahead lies the Night Citadel.",
			]},
	},
	# ---- level 36
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.4, 1.0), "chapter": "FINAL PART  -  THE NIGHT CITADEL",
			"lines": [
				"A bridge of shadow over the void.",
				"At its end: the Night Citadel. No moon, no stars.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Dusk Herald falls and the gates swing open.",
			]},
	},
	# ---- level 37
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The moonless court. Blinders and scouts own the shadows.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Moon Eater is defeated. A single star returns to the sky.",
				"The Star Vault is below.",
			]},
	},
	# ---- level 38
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Star Vault. Stolen stars hang in glass jars.",
				"Listeners hear a heartbeat. Is it the Princess's?",
			]},
		"outro": {"kind": "shardget", "villain": Color(0.7, 0.4, 1.0), "shards": 8,
			"lines": [
				"The Shadow Twin fades. The eighth Dawn Shard glows in the vault.",
				"Eight of eight. The Crystal is whole in {hero}'s hands.",
				"Now, to the throne.",
			]},
	},
	# ---- level 39
	{
		"intro": {"kind": "track", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Shadow Stairs climb forever.",
				"Everything awake wants {hero} dead. At the top: the Night Throne.",
			]},
		"outro": {"kind": "victory", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Night Knight kneels. \"Go,\" he whispers. \"She is waiting.\"",
				"One door left.",
			]},
	},
	# ---- level 40
	{
		"intro": {"kind": "face", "villain": Color(0.7, 0.4, 1.0),
			"lines": [
				"The Night King sits on his throne of shadow.",
				"\"You came all this way for one girl?\"",
				"\"I came for the dawn,\" says {hero}.",
			]},
		"outro": {"kind": "sunrise", "villain": Color(0.7, 0.4, 1.0), "end": true,
			"lines": [
				"The Night King falls. The Dawn Crystal blazes in {hero}'s hands.",
				"Light floods the Citadel. The Princess wakes, free at last.",
				"\"I knew you would come,\" she says.",
				"And over the world, the sun rises once more.",
			]},
	},
]


## The scene to play for a level ("intro" or "outro"), or {} if there is none.
static func get_scene(level: int, which: String) -> Dictionary:
	if level < 0 or level >= SCENES.size():
		return {}
	return SCENES[level].get(which, {})
