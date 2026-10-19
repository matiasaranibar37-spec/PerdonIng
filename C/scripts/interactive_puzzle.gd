extends CanvasLayer

# Señal emitida cuando el jugador introduce el código correcto
signal codigo_correcto

# Código secreto configurado a 3 dígitos (puedes cambiarlo si deseas)
const CODIGO_SECRETO: String = "382"

var codigo_actual: String = ""
var procesando_validacion: bool = false

@onready var display_label: Label = $Control/VBoxContainer/DisplayLabel
@onready var keypad_grid: GridContainer = $Control/VBoxContainer/KeypadGrid

func _ready() -> void:
	# Ocultar la UI al iniciar la escena
	hide()
	actualizar_display()
	_conectar_botones()

# Conecta las señales de clic/disparo de los 9 botones si usas Button o TextureButton
func _conectar_botones() -> void:
	if not keypad_grid:
		return
		
	var numero_index: int = 1
	for child in keypad_grid.get_children():
		if child is Button or child is TextureButton:
			# Si el botón no tiene texto escrito, asignarle su número
			if child.has_method("set_text") and child.text.is_empty():
				child.text = str(numero_index)
			
			var digito = str(numero_index)
			# Conectar la señal 'pressed' de Godot
			if not child.pressed.is_connected(_on_boton_presionado.bind(digito)):
				child.pressed.connect(_on_boton_presionado.bind(digito))
			
			numero_index += 1

# Función invocada cuando cualquiera de los jugadores dispara o presiona un número
func presionar_numero(digito: String) -> void:
	if procesando_validacion:
		return
		
	if codigo_actual.length() < 3:
		codigo_actual += digito
		actualizar_display()
		
		# Validar automáticamente en cuanto se completen los 3 dígitos
		if codigo_actual.length() == 3:
			validar_codigo()

func _on_boton_presionado(digito: String) -> void:
	presionar_numero(digito)

func validar_codigo() -> void:
	procesando_validacion = true
	
	if codigo_actual == CODIGO_SECRETO:
		if display_label:
			display_label.text = "¡ACCESO CONCEDIDO!"
		
		await get_tree().create_timer(0.6).timeout
		hide()
		codigo_actual = ""
		procesando_validacion = false
		codigo_correcto.emit() # Notifica al ascensor para abrir las puertas
	else:
		if display_label:
			display_label.text = "ERROR"
		
		await get_tree().create_timer(0.8).timeout
		codigo_actual = ""
		actualizar_display()
		procesando_validacion = false

func actualizar_display() -> void:
	if display_label:
		display_label.text = codigo_actual if codigo_actual != "" else "___"
