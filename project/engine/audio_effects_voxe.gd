extends RefCounted

# Pass 56, voxE: fantasy creature and game archetype voices. Each one runs natively (purrcore
# dsp/pack_voxe.h) on the pitch synchronous voice engine of the voice pack (pitch marks and PSOLA
# grains with their own throat size) and only ever transforms the voice itself: a growl made from
# the voice's own pulses, a mouth that slurs, a sneer, a scorched top, resonances fed by the voice
# that let go when it stops, copies of the voice. Nothing is added on top and nothing plays in the
# pauses.

const GROUP := "Voice"
const MIX := {"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}

const DEFS: Array[Dictionary] = [
	{
		"id": "dragon_voice", "group": GROUP, "label": "Dragon",
		"blurb": "A dragon speaking: the voice drops and the throat grows to the size of a beast, a chest as big as a room booms under every word, and the top of the voice is scorched into a rough, flickering roar made from the voice's own sound. The sound comes out about 66 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Deeper by", "default": 6.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " semitones"},
			{"key": "size", "label": "Chest size", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "fire", "label": "Scorched throat", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "orc_warlord", "group": GROUP, "label": "Orc Warlord",
		"blurb": "A thick necked, tusked orc chief. The voice's own pulses alternate strong and weak the way a throat growls, so a real growl rattles along at half its pitch, it takes over as the orc gets louder, and stressed syllables come out as a bark. The sound comes out about 45 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Deeper by", "default": 3.0, "min": 0.0, "max": 9.0, "step": 0.1, "unit": " semitones"},
			{"key": "growl", "label": "Growl", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "rage", "label": "Growl when quiet too", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "bark", "label": "Bark", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "goblin_voice", "group": GROUP, "label": "Goblin",
		"blurb": "A goblin: small, sharp and nasal, the mouth pulled into a sneer (the upper part of the voice pushed up while the bottom stays), the melody jumping all over the place and a scratchy unsteadiness in every cycle. The sound comes out about 66 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Higher by", "default": 4.0, "min": 0.0, "max": 9.0, "step": 0.1, "unit": " semitones"},
			{"key": "sneer", "label": "Sneer", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "nasal", "label": "Nasal", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "scratch", "label": "Scratchy", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "bridge_troll", "group": GROUP, "label": "Bridge Troll",
		"blurb": "A huge, slow witted troll. The mouth never quite shapes the words: the shape of the throat and mouth lags behind the voice, so the sounds slur into each other, with a big dull throat. The sound comes out about 66 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Deeper by", "default": 5.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " semitones"},
			{"key": "slur", "label": "Slurred mouth", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "size", "label": "Throat size", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "treant_voice", "group": GROUP, "label": "Treant",
		"blurb": "An ancient walking tree: an enormous voice from deep inside a hollow trunk, every pulse of it ringing the wood, and the voice itself creaks, its pulses now and then catching and stretching like a bending branch. The sound comes out about 45 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Deeper by", "default": 7.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " semitones"},
			{"key": "creak", "label": "Creaking voice", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "hollow", "label": "Hollow trunk", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "elven_voice", "group": GROUP, "label": "Elven Voice",
		"blurb": "A light, clear elven voice with a halo: strings tuned to the note being spoken ring along with it while it speaks and let go when it stops, and the top of the voice twinkles, each high band rising and falling on its own. The sound comes out about 45 ms late.",
		"params": [
			{"key": "halo", "label": "Halo", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "twinkle", "label": "Twinkle", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "light", "label": "Lightness", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "djinn_voice", "group": GROUP, "label": "Djinn from the Lamp",
		"blurb": "Every phrase starts small and tinny inside a brass lamp and, as it goes on, billows out into a vast booming voice, spread wide around you and swirling like smoke. After a pause the next phrase starts back inside the lamp. The sound comes out about 45 ms late.",
		"params": [
			{"key": "rise_s", "label": "Comes out of the lamp over", "default": 1.0, "min": 0.3, "max": 3.0, "step": 0.05, "unit": " s"},
			{"key": "size", "label": "How vast", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "swirl", "label": "Smoke swirl", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "ice_elemental", "group": GROUP, "label": "Ice Elemental",
		"blurb": "A being of ice: a cold, thin voice that frosts over into a whisper of itself, rings like glass on overtones stretched the way ice stretches them while it speaks, and is smeared into the falling zing sound makes running through ice. The sound comes out about 66 ms late.",
		"params": [
			{"key": "glass", "label": "Crystal ring", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "frost", "label": "Frost", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "zing", "label": "Ice zing", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "fae_trickster", "group": GROUP, "label": "Fae Trickster",
		"blurb": "A mischievous fairy: a quick, bright little voice with wings beating in it, a fast flutter of its pitch and loudness, darting to a new place left or right with every syllable. The sound comes out about 45 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Higher by", "default": 3.0, "min": 0.0, "max": 9.0, "step": 0.1, "unit": " semitones"},
			{"key": "flutter", "label": "Wing flutter", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "darting", "label": "Darting about", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "spider_queen", "group": GROUP, "label": "Spider Queen",
		"blurb": "A giant spider that talks: a whispering, many legged voice with a whisper of itself under it, whose s and sh sounds are chopped into the chitter of mandibles. The sound comes out about 66 ms late.",
		"params": [
			{"key": "chitter", "label": "Mandible chitter", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "whisper", "label": "Whisper", "default": 0.45, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "hydra_voice", "group": GROUP, "label": "Hydra",
		"blurb": "Three heads say the same words a moment apart, each with its own throat: a deep snarling head in the middle, a high sharp head on the left and a huge rattling head on the right. The sound comes out about 45 ms late.",
		"params": [
			{"key": "stagger", "label": "Heads out of step", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "snarl", "label": "Snarl", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "width", "label": "Heads apart", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "slime_voice", "group": GROUP, "label": "Slime",
		"blurb": "A talking blob of ooze: the throat bulges, sags and wobbles as the slime reshapes itself, and two slow, sharp resonances wander through the voice and make it gloopy. The sound comes out about 45 ms late.",
		"params": [
			{"key": "ooze", "label": "Ooze", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "gloop", "label": "Gloop", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "harpy_voice", "group": GROUP, "label": "Harpy",
		"blurb": "Half woman, half bird: a high voice with a fast bird's trill in it that breaks into a thin, shrieking screech whenever it gets loud. The sound comes out about 45 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Higher by", "default": 3.0, "min": 0.0, "max": 9.0, "step": 0.1, "unit": " semitones"},
			{"key": "screech", "label": "Screech", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "trill", "label": "Trill", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "leviathan_voice", "group": GROUP, "label": "Leviathan",
		"blurb": "A vast sea creature speaking from the deep: far lower and bigger, its melody drawn out into the long slow swoops of whale song, the voice darkened and smeared as if it had come up through deep water. The sound comes out about 45 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Deeper by", "default": 9.0, "min": 3.0, "max": 16.0, "step": 0.1, "unit": " semitones"},
			{"key": "glide", "label": "Whale song glide", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "deep", "label": "Deep water", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
]
