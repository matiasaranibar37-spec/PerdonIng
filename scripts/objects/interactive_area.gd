extends Area3D
## Área disparable genérica: sirve para la chaqueta (Coat), la llave, el interruptor de la puerta, etc.
## Cuando un jugador le dispara, emite la señal "disparado". Mientras está habilitada brilla
## al apuntarla (grupo "interactuable"); deshabilitada, ya no brilla ni bloquea los disparos.

signal disparado(jugador_id: String)

## Si es false no recibe disparos, no brilla y no tapa a los zombies que tenga detrás.
@export var habilitado: bool = true:
	set(valor):
		habilitado = valor
		collision_layer = 1 if valor else 0
## Si es true, solo reacciona al primer disparo.
@export var una_sola_vez: bool = true
## Giro opcional (radianes por segundo) para objetos que flotan, como la llave.
@export var velocidad_giro: float = 0.0


func _ready() -> void:
	add_to_group("interactuable")
	collision_layer = 1 if habilitado else 0


func _process(delta: float) -> void:
	if velocidad_giro != 0.0:
		rotate_y(velocidad_giro * delta)


# El highlighter pregunta esto antes de hacer brillar el objeto
func puede_interactuar() -> bool:
	return habilitado


# Lo llama player.gd cuando el rayo del disparo golpea esta área
func recibir_disparo(jugador_id: String = "") -> void:
	if not habilitado:
		return
	if una_sola_vez:
		habilitado = false
	disparado.emit(jugador_id)
