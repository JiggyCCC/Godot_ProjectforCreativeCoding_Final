extends Node2D 

@onready var midi = $MidiPlayer
@onready var info_label = $InfoLabel
@onready var backing_timer = $BackingTimer

# Main trombone state
var active_note = -1
var active_midi_note = -1

var slide_offset = 30.0
var target_slide_offset = 30.0

# Pitch and scale settings
var transpose = 0
var root_note = 48 # C

var major_scale = [0, 2, 4, 5, 7, 9, 11]
var minor_scale = [0, 2, 3, 5, 7, 8, 10]

var current_scale = major_scale
var current_scale_name = "Major"

# Keyboard keys mapped to scale degrees and trombone slide positions
var key_notes = {
	KEY_A: {"degree": 0, "slide": 90.0},
	KEY_S: {"degree": 1, "slide": 75.0},
	KEY_D: {"degree": 2, "slide": 62.0},
	KEY_F: {"degree": 3, "slide": 52.0},
	KEY_G: {"degree": 4, "slide": 40.0},
	KEY_H: {"degree": 5, "slide": 28.0},
	KEY_J: {"degree": 6, "slide": 15.0}
}

# Visual and backing music variables
var floating_notes = []

var bass_pattern = [36, 38, 41, 43]
var bass_index = 0

var neon_time = 0.0

func _ready() -> void:
	change_instrument(0, 58)
	change_instrument(1, 32)

	update_label()

	backing_timer.timeout.connect(_on_backing_timer_timeout)

# Updates on-screen instructions
func update_label():
	info_label.text = "A S D F G H J = play trombone notes\n"
	info_label.text += "UP arrow = transpose up | DOWN arrow = transpose down\n"
	info_label.text += "1 = major scale | 2 = minor scale\n"
	info_label.text += "Z = lower key | X = higher key\n"
	info_label.text += "Scale: " + current_scale_name + " | Transpose: " + str(transpose) + " | Root: " + str(root_note)

# Converts a scale degree into a MIDI note
func get_scale_note(degree):
	var octave = degree / current_scale.size()
	var index = degree % current_scale.size()
	var note = root_note + current_scale[index] + (octave * 12) + transpose
	return clamp(note, 0, 127)

# Change the MIDI instrument on a channel
func change_instrument(channel, instrument):
	var midi_event = InputEventMIDI.new()
	midi_event.channel = channel
	midi_event.message = MIDI_MESSAGE_PROGRAM_CHANGE
	midi_event.instrument = instrument
	midi.receive_raw_midi_message(midi_event)

#starting and stopping Midi notes
func send_note_on(note, channel, velocity := 100):
	var m = InputEventMIDI.new()
	m.message = MIDI_MESSAGE_NOTE_ON
	m.pitch = clamp(note, 0, 127)
	m.velocity = velocity
	m.channel = channel
	midi.receive_raw_midi_message(m)


func send_note_off(note, channel):
	var m = InputEventMIDI.new()
	m.message = MIDI_MESSAGE_NOTE_OFF
	m.pitch = clamp(note, 0, 127)
	m.velocity = 0
	m.channel = channel
	midi.receive_raw_midi_message(m)

# Plays a backing note for a short duration
func play_short_note(note, duration, channel):
	send_note_on(note, channel)
	await get_tree().create_timer(duration).timeout
	send_note_off(note, channel)

# keyboard controls from input
func _input(event):
	if event is InputEventKey:

		if event.pressed and not event.is_echo():

			if event.keycode == KEY_UP:
				transpose += 1
				print("Transpose up: ", transpose)
				update_label()
				return

			if event.keycode == KEY_DOWN:
				transpose -= 1
				print("Transpose down: ", transpose)
				update_label()
				return

			if event.keycode == KEY_1:
				current_scale = major_scale
				current_scale_name = "Major"
				print("Major scale")
				update_label()
				return

			if event.keycode == KEY_2:
				current_scale = minor_scale
				current_scale_name = "Minor"
				print("Minor scale")
				update_label()
				return

			if event.keycode == KEY_Z:
				root_note -= 1
				root_note = clamp(root_note, 0, 127)
				print("Root note lowered: ", root_note)
				update_label()
				return

			if event.keycode == KEY_X:
				root_note += 1
				root_note = clamp(root_note, 0, 127)
				print("Root note raised: ", root_note)
				update_label()
				return

			if event.keycode in key_notes:
				var data = key_notes[event.keycode]
				var degree = data["degree"]
				var note = get_scale_note(degree)
				var slide_pos = data["slide"]

				if active_midi_note != -1:
					send_note_off(active_midi_note, 0)

				active_note = degree
				active_midi_note = note

				target_slide_offset = slide_pos
				send_note_on(note, 0)
				create_floating_note(note)

		elif not event.pressed:
			if event.keycode in key_notes:
				if active_midi_note != -1:
					send_note_off(active_midi_note, 0)
					active_note = -1
					active_midi_note = -1

# Updates animation values every frame
func _process(delta):
	slide_offset = lerp(slide_offset, target_slide_offset, 8.0 * delta)

	for i in range(floating_notes.size() - 1, -1, -1):
		floating_notes[i]["pos"].y -= 40 * delta
		floating_notes[i]["life"] -= delta

		if floating_notes[i]["life"] <= 0:
			floating_notes.remove_at(i)

	neon_time += delta

	queue_redraw()

# floating music note visual
func create_floating_note(note):
	var note_obj = {
		"pos": Vector2(770, 370),
		"life": 1.5,
		"note": note
	}

	floating_notes.append(note_obj)

# repeating bass pattern
func _on_backing_timer_timeout():
	var note = bass_pattern[bass_index]
	play_short_note(note, 0.35, 1)
	bass_index = (bass_index + 1) % bass_pattern.size()

func _draw():
	draw_background()
	draw_trombone()
	draw_floating_notes()

# jazz laneway background
func draw_background():
	var vs = get_viewport_rect().size

	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.08, 0.06, 0.12))

	draw_rect(Rect2(0, 0, 180, vs.y), Color(0.18, 0.12, 0.18))
	draw_rect(Rect2(vs.x - 180, 0, 180, vs.y), Color(0.12, 0.16, 0.22))

	draw_rect(Rect2(0, vs.y * 0.72, vs.x, vs.y * 0.28), Color(0.15, 0.15, 0.18))

	var glow1 = 0.7 + 0.3 * sin(neon_time * 2.0)
	var glow2 = 0.7 + 0.3 * sin(neon_time * 1.6)

	draw_rect(Rect2(30, 80, 120, 40), Color.from_hsv(0.88, 0.8, glow1))
	draw_rect(Rect2(vs.x - 150, 140, 100, 40), Color.from_hsv(0.55, 0.8, glow2))
	draw_rect(Rect2(45, 180, 90, 30), Color.from_hsv(0.15, 0.8, glow2))

	for i in range(5):
		draw_rect(Rect2(35, 260 + i * 70, 50, 35), Color(0.95, 0.7, 0.25, 0.7))
		draw_rect(Rect2(vs.x - 85, 240 + i * 75, 40, 30), Color(0.4, 0.9, 1.0, 0.7))

	draw_circle(Vector2(220, 130), 14, Color(1.0, 0.4, 0.6))
	draw_circle(Vector2(280, 165), 12, Color(0.3, 0.9, 1.0))
	draw_circle(Vector2(330, 120), 10, Color(1.0, 0.8, 0.2))
	draw_circle(Vector2(850, 110), 13, Color(0.8, 0.3, 1.0))
	draw_circle(Vector2(910, 160), 11, Color(0.2, 1.0, 0.8))

# interactive trombone
func draw_trombone():
	var base_x = 460
	var base_y = 390

	draw_circle(Vector2(base_x, base_y), 40, Color(0.95, 0.76, 0.15))

	draw_rect(Rect2(base_x, base_y - 10, 180, 20), Color(0.95, 0.76, 0.15))

	draw_rect(Rect2(base_x - 40, base_y - 6, 40, 12), Color(0.8, 0.7, 0.2))

	draw_rect(Rect2(base_x + 150, base_y - 40, 10, 80), Color(0.95, 0.76, 0.15))

	draw_rect(Rect2(base_x + 160, base_y - 26, 130 + slide_offset, 8), Color(0.98, 0.85, 0.25))
	draw_rect(Rect2(base_x + 160, base_y + 18, 130 + slide_offset, 8), Color(0.98, 0.85, 0.25))
	draw_rect(Rect2(base_x + 280 + slide_offset, base_y - 26, 8, 52), Color(0.98, 0.85, 0.25))

	draw_circle(Vector2(base_x + 210 + slide_offset, base_y + 45), 18, Color(1.0, 0.78, 0.62))

# floating note visuals
func draw_floating_notes():
	for n in floating_notes:
		var p = n["pos"]
		var life = n["life"]
		var alpha = clamp(life / 1.5, 0.0, 1.0)
		var col = Color(1.0, 1.0, 1.0, alpha)

		draw_circle(Vector2(p.x, p.y), 8, col)
		draw_rect(Rect2(p.x + 5, p.y - 28, 4, 28), col)
		draw_circle(Vector2(p.x + 16, p.y - 8), 8, col)
		draw_rect(Rect2(p.x + 21, p.y - 36, 4, 28), col)
