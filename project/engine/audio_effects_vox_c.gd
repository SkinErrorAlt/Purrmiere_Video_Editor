extends RefCounted

# Unique voices: voices nobody else has. The voice of a thing (wind, fire, water, bells, sparks, a
# modem), a voice played on a piano, a voice trapped in an object, backwards speech, a made up
# language and more. Each one only transforms the voice itself (resynthesis, resonance, filtering,
# modulation, layered copies of it): no sound effects are added and nothing plays on its own in the
# pauses. All of them run natively (purrcore/src/dsp/vox_c_*.h), keep time on the absolute clock and
# so sound the same from any start point.

const G_VOICE := "Voice"
const MIX := {"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}

const DEFS: Array[Dictionary] = [
	{
		"id": "wind_voice", "group": G_VOICE, "label": "Voice of the Wind",
		"blurb": "The words are whispered by the wind itself: rushing air takes the shape of the voice, and a ghostly howl drawn out of those words rises and falls with the speaker's own melody up where wind whistles, while gusts swell and bend it.",
		"params": [
			{"key": "howl", "label": "Howl", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "howl_up", "label": "Howl above the voice", "default": 1.0, "choices": ["One octave", "Two octaves", "Three octaves"]},
			{"key": "gusts", "label": "Gusts", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "fire_voice", "group": G_VOICE, "label": "Voice of Fire",
		"blurb": "The words are spoken by roaring, crackling flames: the fire takes the shape of the voice, crackles harder on loud syllables and flickers. For fire demons, burning ghosts and whatever lives in the furnace.",
		"params": [
			{"key": "crackle", "label": "Crackle", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice in it", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "water_voice", "group": G_VOICE, "label": "Voice of Water",
		"blurb": "The words are made of bubbling water: hundreds of bubbles a second, each a tiny rising plip, take the shape of the voice and bubble only where it speaks. For river spirits, drowned things and creatures from the deep.",
		"params": [
			{"key": "bubbles", "label": "Bubbles", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "size", "label": "Bubble size", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice in it", "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "bell_voice", "group": G_VOICE, "label": "Bell Voice",
		"blurb": "The words are rung out of bells: every syllable tunes a bell to the note being spoken (octaves up, bigger bells lower) and the voice itself rings it, the bells take the shape of the vowels, and their resonance rings on after the words with the hum and shimmer of a real cast bell.",
		"params": [
			{"key": "ring", "label": "Ring on", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "size", "label": "Bell size", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "tesla_voice", "group": G_VOICE, "label": "Tesla Coil Voice",
		"blurb": "The words are spoken by a singing Tesla coil: high voltage sparks fire at the voice's pitch, crackle through the s and t sounds and take the shape of the vowels. The sparks can follow the voice, snap to musical notes or hold one note.",
		"params": [
			{"key": "notes", "label": "Sparks play", "default": 0.0, "choices": ["The voice's pitch", "Musical notes", "One note"]},
			{"key": "arc", "label": "Arc", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "codec_breakup", "group": G_VOICE, "label": "AI Voice Breaking Up",
		"blurb": "The voice squeezed through an AI voice codec at far too low a bitrate: the shape of the mouth arrives in coarse steps, the pitch is snapped and rebuilt as clean metallic harmonics, the top end goes, and now and then the model glitches, sticking on a sound, slipping into someone else's throat or jumping in pitch. The sound comes out about 21 ms late.",
		"params": [
			{"key": "breakup", "label": "Breakup", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "glitches", "label": "Glitches", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "metal", "label": "Metallic", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "talking_piano", "group": G_VOICE, "label": "Talking Piano",
		"blurb": "The voice played on a piano, a music box or a toy piano: many times a second the strongest notes in the voice are struck at the loudness they had, the way the famous speaking piano works, so the keys say the words. The notes land about 50 ms after the words.",
		"params": [
			{"key": "instrument", "label": "Instrument", "default": 0.0, "choices": ["Piano", "Music box", "Toy piano"]},
			{"key": "speed", "label": "Strikes per second", "default": 16.0, "min": 8.0, "max": 30.0, "step": 1.0},
			{"key": "ring", "label": "Ring", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "trapped_inside", "group": G_VOICE, "label": "Trapped Inside",
		"blurb": "A voice shut inside a coffin, a wardrobe, an oil drum, a glass jar or the boot of a car, heard from outside: the inside rings with its own size, the walls take the top off and ring with their own material, and a little leaks through the gaps.",
		"params": [
			{"key": "object", "label": "Inside", "default": 0.0, "choices": ["Coffin", "Wardrobe", "Oil drum", "Glass jar", "Car boot"]},
			{"key": "muffle", "label": "Thick walls", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "backwards_speech", "group": G_VOICE, "label": "Backwards Speech",
		"blurb": "Every short piece of the voice is played backwards where it stands, so the words stay in order but each sound runs in reverse: the uncanny, half understandable speech of a dream room. Longer pieces turn whole words backwards. The sound comes out one piece late (about a quarter of a second as set), so leave that much room at the end of the clip.",
		"params": [
			{"key": "piece_s", "label": "Piece length", "default": 0.2, "min": 0.06, "max": 0.6, "step": 0.01, "unit": " s"},
			{"key": "smooth", "label": "Smooth joins", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "room", "label": "Room", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "unknown_language", "group": G_VOICE, "label": "Unknown Language",
		"blurb": "The voice speaks a language nobody knows: its sounds are cut into syllable sized pieces and shuffled within each group of three, some played backwards, so the voice, rhythm and melody stay but the words become a believable foreign tongue. Each language number shuffles its own way, for alien, fantasy and creature dialogue. The sound comes out three syllables late (about 0.35 s as set).",
		"params": [
			{"key": "syllable_s", "label": "Syllable length", "default": 0.11, "min": 0.05, "max": 0.25, "step": 0.01, "unit": " s"},
			{"key": "backwards", "label": "Backwards sounds", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "language", "label": "Language", "default": 1.0, "min": 1.0, "max": 12.0, "step": 1.0},
			MIX,
		],
	},
	{
		"id": "transformation", "group": G_VOICE, "label": "Transformation",
		"blurb": "The speaker turns into something else during the clip. Until the start time it is their own voice; then over the time it takes it slides into a beast (pitch and throat sink, a growl and a second throat grow in), a machine (the melody flattens to one note, metal rings and a modulator buzzes) or a wraith (the voice thins and turns to breath with a cold echo). Times count from the start of the clip. The sound comes out about 40 ms late.",
		"params": [
			{"key": "into", "label": "Turns into", "default": 0.0, "choices": ["Beast", "Machine", "Wraith"]},
			{"key": "begins_s", "label": "Starts at", "default": 1.0, "min": 0.0, "max": 60.0, "step": 0.1, "unit": " s"},
			{"key": "takes_s", "label": "Takes", "default": 4.0, "min": 0.2, "max": 30.0, "step": 0.1, "unit": " s"},
			MIX,
		],
	},
	{
		"id": "premonition", "group": G_VOICE, "label": "Premonition",
		"blurb": "A whisper says every word a moment before the voice does, drifting around the head in a cold space, like hearing what is about to be said. The voice itself comes out late by the lead time so the whisper can go first: slide the clip earlier by that much and leave that much room at its end.",
		"params": [
			{"key": "ahead_s", "label": "Whisper ahead by", "default": 0.5, "min": 0.15, "max": 1.2, "step": 0.01, "unit": " s"},
			{"key": "whisper", "label": "Whisper", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "space", "label": "Space", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "voice_scrambler", "group": G_VOICE, "label": "Voice Scrambler",
		"blurb": "The voice through an old analogue speech scrambler, turned into garbled alien chatter. Spectrum flip turns its frequencies upside down, Rolling code flips it around a carrier that hops with the key, and Band swap trades parts of the voice around. Each one undoes itself, so a puzzle can hide a message: put the scrambled sound through the scrambler again with the same settings, starting at the same point, and the words come back.",
		"params": [
			{"key": "method", "label": "Method", "default": 0.0, "choices": ["Spectrum flip", "Rolling code", "Band swap"]},
			{"key": "key", "label": "Key", "default": 7.0, "min": 1.0, "max": 99.0, "step": 1.0},
			{"key": "band", "label": "Band", "default": 0.0, "choices": ["Telephone", "Wide"]},
			MIX,
		],
	},
	{
		"id": "down_the_well", "group": G_VOICE, "label": "Down the Well",
		"blurb": "A voice calling up from the bottom of a deep stone well: the narrow shaft rings with a fluttering, pitched echo between its walls and the sound climbs and falls back down the depth of the shaft.",
		"params": [
			{"key": "depth", "label": "Depth", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "stone", "label": "Stone ring", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "dialup_voice", "group": G_VOICE, "label": "Dial-Up Voice",
		"blurb": "The words spoken by a dial-up modem: screeching, warbling data tones take the shape of the voice and come down a phone line. For retro internet horror, hacking scenes and ARGs.",
		"params": [
			{"key": "warble", "label": "Warble", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice in it", "default": 0.12, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
]
