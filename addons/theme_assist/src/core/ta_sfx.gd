class_name TaSfx
extends Object

# AGENT: Tiny original UI ticks. Generated PCM, no third-party samples.
# INVARIANT: named streams return AudioStreamWAV. muted play_on is a no-op.
# Reduced-motion does not mute — that is a separate accessibility flag.
# DO NOT: Bundle other people's wavs. Do not require a mixer bus.

## Runtime mute. Independent of TaJuice.reduced_motion.
static var muted: bool = false
## Mixer bus for kit sounds. Set "UI" or "SFX" so Options can balance them.
static var bus: StringName = &"Master"
static var _cache: Dictionary = {}

const NAMES := [
	"hover",
	"press",
	"confirm",
	"deny",
	"open",
	"close",
	"notify",
	"celebrate",
	"level_up",
]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func stream(sfx_name: String) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var made := _make(sfx_name)
	if made != null:
		_cache[sfx_name] = made
	return made


## Named sounds. Generated once, then shared from the cache.
static func hover() -> AudioStreamWAV:
	return stream("hover")


static func press() -> AudioStreamWAV:
	return stream("press")


static func confirm() -> AudioStreamWAV:
	return stream("confirm")


static func deny() -> AudioStreamWAV:
	return stream("deny")


static func open() -> AudioStreamWAV:
	return stream("open")


static func close() -> AudioStreamWAV:
	return stream("close")


static func notify() -> AudioStreamWAV:
	return stream("notify")


static func celebrate() -> AudioStreamWAV:
	return stream("celebrate")


static func level_up() -> AudioStreamWAV:
	return stream("level_up")


static func is_muted() -> bool:
	return muted


## Play `sound` on a one-shot child player. No-op if muted or null.
static func play_on(host: Node, sound: AudioStream) -> void:
	if sound == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	if is_muted():
		return
	var player := AudioStreamPlayer.new()
	host.add_child(player)
	player.stream = sound
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	player.finished.connect(player.queue_free)
	player.play()


static func _make(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"hover":
			return _gen_hover()
		"press":
			return _gen_press()
		"confirm":
			return _gen_confirm()
		"deny":
			return _gen_deny()
		"open":
			return _gen_open()
		"close":
			return _gen_close()
		"notify":
			return _gen_notify()
		"celebrate":
			return _gen_celebrate()
		"level_up":
			return _gen_level_up()
		_:
			return null


static func _gen_hover() -> AudioStreamWAV:
	return _blip(
		TaDefaults.SFX_HOVER_HZ,
		TaDefaults.SFX_HOVER_SECONDS,
		TaDefaults.SFX_HOVER_VOLUME
	)


static func _gen_press() -> AudioStreamWAV:
	return _blip(
		TaDefaults.SFX_PRESS_HZ,
		TaDefaults.SFX_PRESS_SECONDS,
		TaDefaults.SFX_PRESS_VOLUME
	)


static func _gen_confirm() -> AudioStreamWAV:
	return _blip(
		TaDefaults.SFX_CONFIRM_HZ,
		TaDefaults.SFX_BLIP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_deny() -> AudioStreamWAV:
	return _sweep(
		TaDefaults.SFX_DENY_HZ * 2.0,
		TaDefaults.SFX_DENY_HZ,
		TaDefaults.SFX_DENY_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_open() -> AudioStreamWAV:
	return _sweep(
		TaDefaults.SFX_OPEN_HZ,
		TaDefaults.SFX_OPEN_HZ * 2.0,
		TaDefaults.SFX_SWEEP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_close() -> AudioStreamWAV:
	return _sweep(
		TaDefaults.SFX_CLOSE_HZ * 2.0,
		TaDefaults.SFX_CLOSE_HZ,
		TaDefaults.SFX_SWEEP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_notify() -> AudioStreamWAV:
	return _arpeggio(
		PackedFloat32Array([TaDefaults.SFX_NOTIFY_HZ, TaDefaults.SFX_NOTIFY_HZ_B]),
		TaDefaults.SFX_BLIP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_celebrate() -> AudioStreamWAV:
	return _arpeggio(
		PackedFloat32Array([
			TaDefaults.SFX_CELEBRATE_HZ_1,
			TaDefaults.SFX_CELEBRATE_HZ_2,
			TaDefaults.SFX_CELEBRATE_HZ_3,
		]),
		TaDefaults.SFX_BLIP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _gen_level_up() -> AudioStreamWAV:
	return _arpeggio(
		PackedFloat32Array([
			TaDefaults.SFX_LEVEL_HZ_1,
			TaDefaults.SFX_LEVEL_HZ_2,
			TaDefaults.SFX_LEVEL_HZ_3,
			TaDefaults.SFX_LEVEL_HZ_4,
		]),
		TaDefaults.SFX_BLIP_SECONDS,
		TaDefaults.SFX_BLIP_VOLUME
	)


static func _blip(hz: float, seconds: float, volume: float) -> AudioStreamWAV:
	return _wav(_pcm(hz, seconds, volume, hz, false))


static func _sweep(hz0: float, hz1: float, seconds: float, volume: float) -> AudioStreamWAV:
	return _wav(_pcm(hz0, seconds, volume, hz1, true))


static func _arpeggio(
		notes: PackedFloat32Array,
		note_seconds: float,
		volume: float
	) -> AudioStreamWAV:
	var data := PackedByteArray()
	for hz in notes:
		data.append_array(_pcm(hz, note_seconds, volume, hz, false))
	return _wav(data)


static func _pcm(
		hz0: float,
		seconds: float,
		volume: float,
		hz1: float,
		sweep: bool
	) -> PackedByteArray:
	var rate := TaDefaults.SFX_RATE
	var count := maxi(8, int(rate * seconds))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var env := 1.0 - float(i) / float(count)
		var hz := hz0
		if sweep:
			hz = lerpf(hz0, hz1, float(i) / float(count))
		# Accumulate phase. sin(TAU * hz(t) * t) overshoots a sweep to twice its range.
		phase += TAU * hz / float(rate)
		var sample := int(sin(phase) * env * volume * 32767.0)
		sample = clampi(sample, -32767, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return data


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TaDefaults.SFX_RATE
	stream.stereo = false
	stream.data = data
	return stream
