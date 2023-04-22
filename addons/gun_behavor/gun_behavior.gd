@icon("res://addons/gun_behavor/icon.svg")
extends Node

enum ReloadType { MULTIPLE, SINGLE }
enum ActionType { SINGLE, DOUBLE, SEMI_AUTOMATIC, BURST, FULL_AUTOMATIC }
enum State { HOLSTERED, SAFE, READY, SHOOT, PRE_CYCLE, CYCLING, EMPTY, RELOADING }

signal state_changed(new_state, previous_state)
signal shot
signal cycle_started
signal cycle_finished
signal trigger_pulled
signal trigger_released
signal emptied
signal reload_started
signal reload_finished
signal round_inserted
signal chamber_filled(chamber)
signal mode_changed(new_mode)
signal reserve_added

## The state the gun will be in, on ready.
@export var default_state: State = State.HOLSTERED

## Whether the chambers will be filled with ammo on ready. This can be used for picked up unloaded weapons, or for unloaded weapons loaded from a save file etc.
@export var fill_chamber_on_ready: bool = true

## The amount of ammo that is currently in the magazine.
@export_range(0, 9999, 1, "or_greater") var ammo: int = 1

## The amount of reserve ammo, that will be reduced when reloading.
@export_range(0, 9999, 1, "or_greater") var reserve_ammo: int = 0


@export_group("Action")

## How fast the action of the gun cycles in rounds per minute.
@export_range(0, 3500) var rate_of_fire: int = 0:
	set(value):
		if value == rate_of_fire:
			return
		rate_of_fire = value

## How many shots to fire, when using burst mode.
@export var burst_amount: int = 3

## The available firing modes for this gun.
@export var modes: Array[ActionType] = [ActionType.SEMI_AUTOMATIC]

## How many chambers/barrels the gun has. Most guns will have `1`, whereas double-barrel shotguns will have `2`. 
@export_range(1, 10, 1, "or_greater") var chambers: int = 1


@export_group("Reload")

## The reload speed. Use `0` to implement your own reload time, and by manually calling `reload()`.
@export_range(0, 10) var reload_time: float = 1

## How the ammo is replenished. `MULTIPLE` will fill up with available ammo, whereas `SINGLE` will insert one round at a time.
@export var reload_type: ReloadType = ReloadType.MULTIPLE

## Whether the gun can be topped up with one additional bullet from reloading.
@export var plus_one: bool = true


@export_group("Ammunition")

## How many rounds can fit in the magazine.
@export_range(-1, 9999, 1, "or_greater") var magazine_size: int = 1

## The maximum number of rounds that can be stored in reserve. Use `-1` for infinite, or to handle the reserve yourself.
@export_range(-1, 9999, 1, "or_greater") var max_reserve: int = 0

## The cost per shot. Could be used for upgraded weapons, or higher damager weapons that share ammo pools with others.
@export_range(0, 10, 1, "or_greater") var ammo_cost: int = 1

@onready var _mode: ActionType = modes.front():
	set(value):
		if value == _mode:
			return
		
		_mode = value
		mode_changed.emit(_mode)
@onready var _state: State = default_state:
	set(value):
		if value == _state:
			return
		_previous_state = _state
		_state = value
		state_changed.emit(_state, _previous_state)

var _chambers: PackedInt32Array = [0]
var _current_chamber: int = 0
var _previous_state: State
var _burst_count: int = 1
var _is_bursting: bool = false

var _is_trigger_pulled: bool = false:
	set(value):
		if value == _is_trigger_pulled:
			return
		_is_trigger_pulled = value
		if _is_trigger_pulled:
			trigger_pulled.emit()
		else:
			trigger_released.emit()

func _ready() -> void:
	_chambers.resize(chambers)
	_chambers.fill(0)
	
	if fill_chamber_on_ready and ammo:
		_chambers.fill(ammo_cost)
		ammo -= chambers * ammo_cost
		for chamber in chambers:
			chamber_filled.emit(chamber)


func pull_trigger() -> void:
	if is_holstered() or is_safe():
		return
	
	_is_trigger_pulled = true
	
	if can_shoot():
		_change_state(State.SHOOT)


func release_trigger() -> void:
	if is_holstered():
		return
	
	_is_trigger_pulled = false


func _change_state(new_state: State) -> void:
	if _state == new_state:
		return
	
	match new_state:
		State.HOLSTERED:
			pass
		
		State.SAFE:
			pass
		
		State.READY:
			pass
		
		State.SHOOT:
			if is_holstered() or not _state in [State.READY] or not can_shoot():
				return
		
		_:
			if is_holstered():
				return
	
	_state = new_state
	
	match _state:
		State.HOLSTERED:
			pass
		
		State.SAFE:
			release_trigger()
		
		State.READY:
			if _is_bursting or (_mode == ActionType.FULL_AUTOMATIC and _is_trigger_pulled):
				_change_state(State.SHOOT)
		
		State.SHOOT:
			shoot()
			_change_state(State.PRE_CYCLE)
		
		State.PRE_CYCLE:
			if ammo <= 0:
				_change_state(State.EMPTY)
			elif _mode != ActionType.SINGLE:
				_change_state(State.CYCLING)
		
		State.CYCLING:
			cycle_started.emit()
			if rate_of_fire > 0:
				await get_tree().create_timer(60.0/rate_of_fire).timeout
			cycle_finished.emit()
			cycle()
		
		State.EMPTY:
			_burst_count = 1
			_is_bursting = false
			emptied.emit()
		
		State.RELOADING:
			reload_started.emit()
			if reload_time > 0:
				await  get_tree().create_timer(reload_time).timeout
			reload_finished.emit()
			reload()


func shoot() -> void:
	if is_holstered():
		return
	
	_chambers[_current_chamber] -= ammo_cost
	shot.emit()
	
	if _mode == ActionType.BURST and _burst_count < burst_amount:
		_burst_count += 1
		_is_bursting = true
	else:
		_burst_count = 1
		_is_bursting = 0


func cycle() -> void:
	for chamber in chambers:
		if _chambers[chamber] < ammo_cost:
			_chambers[chamber] += ammo_cost
			chamber_filled.emit(chamber)
			ammo -= ammo_cost
	
	_change_state(State.READY)


func insert_round(amount: int = 1) -> void:
	if ammo < magazine_size:
		ammo += amount


func reload(amount: int = 0) -> void:
	if amount:
		ammo = amount
		return
	
	if not can_reload():
		return
	
	var _to_insert = magazine_size - get_shots_remaining()
	
	if plus_one and ammo > 0:
		_to_insert += 1
	
	if max_reserve > -1:
		if reserve_ammo < _to_insert:
			_to_insert = reserve_ammo
		reserve_ammo -= _to_insert
	
	ammo += _to_insert
	
	_change_state(State.PRE_CYCLE)


func start_reload() -> void:
	if is_holstered() or not can_reload() or ammo == magazine_size:
		return
	
	_change_state(State.RELOADING)


func make_holstered() -> void:
	_change_state(State.HOLSTERED)


func make_safe() -> void:
	_change_state(State.SAFE)


func make_ready() -> void:
	_change_state(State.READY)


func next_mode() -> void:
	if is_holstered() or modes.is_empty():
		return
	
	var _index = modes.find(_mode)
	var _next = _index + 1
	if _next >= modes.size():
		_next = 0
	_mode = modes[_next]


func prev_mode() -> void:
	if is_holstered() or modes.is_empty():
		return
	
	var _index = modes.find(_mode)
	var _next = _index - 1
	if _next < 0:
		_next = modes.size()
	_mode = modes[_next]


func is_equipped() -> bool:
	return _state != State.HOLSTERED


func is_holstered() -> bool:
	return _state == State.HOLSTERED


func is_safe() -> bool:
	return _state == State.SAFE


func is_ready() -> bool:
	return _state == State.READY


func get_state_name() -> String:
	return State.keys()[_state]


func get_mode_name() -> String:
	return ActionType.keys()[_mode]


func add_reserve(amount: int) -> void:
	reserve_ammo += amount
	reserve_added.emit()


func get_shots_remaining() -> int:
	return (ammo / ammo_cost) + _chambers.count(ammo_cost)


func can_shoot() -> bool:
	return _chambers.count(ammo_cost) > 0


func can_reload() -> bool:
	if plus_one:
		return ammo < magazine_size
	else:
		return get_shots_remaining() < magazine_size
