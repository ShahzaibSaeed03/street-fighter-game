class_name Heroes
extends RefCounted
## Heroes.gd: the three playable heroes. Each one has a bonus, a power and her/his own look.

const LIST: Array[Dictionary] = [
	{"id": "ayaan", "name": "Jake", "title": "The Shadow Knight", "price": 0,
		"power": "Shadow Step", "desc": "Quick on his feet. 12% faster movement.",
		"speed": 1.12, "hp": 0, "dmg": 1.0, "arrows": 0, "arrow_mult": 1.0,
		"cape": Color(0.66, 0.10, 0.15), "plume": Color(0.78, 0.12, 0.16), "female": false},
	{"id": "zara", "name": "Maya", "title": "The Keen Archer", "price": 800,
		"power": "Keen Eye", "desc": "+6 arrows and 20% more arrow damage.",
		"speed": 1.0, "hp": 0, "dmg": 1.0, "arrows": 6, "arrow_mult": 1.2,
		"cape": Color(0.20, 0.55, 0.35), "plume": Color(0.30, 0.90, 0.50), "female": true},
	{"id": "kabir", "name": "Marcus", "title": "The Iron Guard", "price": 1200,
		"power": "Iron Guard", "desc": "+20 max HP and 15% less damage taken, but 4% slower.",
		"speed": 0.96, "hp": 20, "dmg": 0.85, "arrows": 0, "arrow_mult": 1.0,
		"cape": Color(0.15, 0.25, 0.60), "plume": Color(0.30, 0.50, 1.00), "female": false},
]
