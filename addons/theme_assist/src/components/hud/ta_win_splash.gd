class_name TaWinSplash
extends PanelContainer

# AGENT: Oversized win / combo splash. Canvas only.
# INVARIANT: present() punches the panel. set_amount is the big number.
# DO NOT: Own score. Do not autoload.

## Big "WIN" + amount. Call present() on a payout.

var _col: VBoxContainer
var _title: Label
var _amount: Label


func _init() -> void:
	theme_type_variation = "TaWinSplash"
	_col = VBoxContainer.new()
	add_child(_col)
	_title = Label.new()
	_title.text = "WIN"
	_title.theme_type_variation = "TaTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_title)
	_amount = Label.new()
	_amount.text = "+0"
	_amount.theme_type_variation = "TaSuccessLabel"
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_amount)
	refresh_metrics()


func refresh_metrics() -> void:
	custom_minimum_size.x = TaLook.metric(
			TaDefaults.SPLASH_MIN_WIDTH, TaDefaults.PIXEL_SPLASH_MIN_WIDTH
	)


func set_title(text: String) -> void:
	_title.text = text


func set_amount(text: String) -> void:
	_amount.text = text


func present() -> void:
	visible = true
	TaJuice.punch(self, TaDefaults.FANFARE_CELEBRATE_PUNCH)
