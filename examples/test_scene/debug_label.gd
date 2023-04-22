extends HBoxContainer

@export var target: Node
@export var key: String
@export var custom_label: String
@export var enum_name: String
@export var method_name: String

@onready var key_label: Label = $KeyLabel
@onready var value_label: Label = $ValueLabel

func _ready() -> void:
	if not target or (key.is_empty() and method_name.is_empty()):
		hide()
	else:
		var _value = ""
		
		if not custom_label.is_empty():
			_value = custom_label
		elif not method_name.is_empty():
			_value = method_name.capitalize()
		else:
			_value = key.capitalize()
		
		key_label.text = "%s:" % _value


func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	var _value = var_to_str(target.get(key))
	
	if not enum_name.is_empty():
		_value = target[enum_name].keys()[target.get(key)]
	elif not method_name.is_empty() and target.has_method(method_name):
		_value = var_to_str(target.call(method_name))
	
	value_label.text = _value
