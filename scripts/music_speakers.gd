extends AudioStreamPlayer

# Conectamos un detector para cuando se encienda la música
func _ready() -> void:
	# Nos conectamos a la señal nativa 'finished' o escuchamos el cambio de estado
	# O mejor aún: detectamos cuando la música empieza a sonar.
	pass

# En Godot 4, podemos usar la señal 'finished' o interceptar con _notification
func _notification(what: int) -> void:
	# NOTIFICATION_INTERNAL_PROCESS o cuando cambia el estado de reproducción
	pass
func _process(_delta: float) -> void:
	if playing:
		# Avisa a todos los zombies del grupo "agonia_speakers"
		get_tree().call_group("agonia_speakers", "reproducir_agonia")
		set_process(false) # Desactivamos el proceso para que solo lo ejecute una vez
