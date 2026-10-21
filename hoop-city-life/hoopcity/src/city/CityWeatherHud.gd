extends Control
## Delicate rain/snow + gray clouds, on a canvas BELOW the status HUD.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func _process(_delta: float) -> void:
	if WeatherArt.weather() in ["rain", "snow", "cloudy"]:
		queue_redraw()

func _draw() -> void:
	var w: String = WeatherArt.weather()
	if w not in ["rain", "snow", "cloudy"]:
		return
	var sz: Vector2 = size
	if sz.x < 8.0:
		sz = get_viewport_rect().size
	WeatherArt.draw_sky_weather(self, Vector2.ZERO, sz, Time.get_ticks_msec() / 1000.0, sz.y * 0.92)
