extends Node

@export var max_signal_logs: int = 20

@onready var gun_behavior = $GunBehavior
@onready var signal_log: RichTextLabel = %SignalLog

var _signal_logs: PackedStringArray

var _signals = [
	"cycle_finished",
	"cycle_started",
	"emptied",
	"reload_finished",
	"reload_started",
	"round_inserted",
	"shot",
	"trigger_pulled",
	"trigger_released",
	"reserve_added",
]
var _signals_arg1 = [
	"chamber_filled",
	"mode_changed",
]
var _signals_arg2 = [
	"state_changed",
]

func _ready() -> void:
	for _signal in _signals:
		gun_behavior[_signal].connect(add_signal_log.bind(_signal))
	for _signal in _signals_arg1:
		gun_behavior[_signal].connect(func(arg1): add_signal_log("%s %s" % [_signal, arg1]))
	for _signal in _signals_arg2:
		gun_behavior[_signal].connect(func(arg1, arg2): add_signal_log("%s %s %s" % [_signal, arg1, arg2]))


func add_signal_log(text: String) -> void:
	_signal_logs.insert(0, text)
	if _signal_logs.size() > max_signal_logs:
		_signal_logs.resize(max_signal_logs)
	signal_log.text = "\n".join(_signal_logs)


func _on_holster_pressed() -> void:
	if gun_behavior.is_holstered():
		gun_behavior.make_ready()
	else:
		gun_behavior.make_holstered()
