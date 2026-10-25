extends Node
## Hace brillar levemente los objetos del grupo "interactuable" cuando
## algún puntero (P1 o P2) apunta hacia ellos.
##
## Para que un objeto brille necesita:
##  1. Estar en el grupo "interactuable" (Nodo > pestaña Nodo > Grupos).
##  2. Tener un colisionable (Area3D / StaticBody3D con CollisionShape3D) en la capa 1,
##     igual que lo que el jugador golpea al disparar.
##  3. (Opcional) un método puede_interactuar() -> bool; si devuelve false, no brilla.

const GRUPO: String = "interactuable"

@export var color_brillo: Color = Color(1.0, 0.9, 0.55)
@export_range(0.0, 1.0) var intensidad_min: float = 0.08
@export_range(0.0, 1.0) var intensidad_max: float = 0.20
@export var velocidad_pulso: float = 4.0
@export_flags_3d_physics var mascara_colision: int = 1
@export var alcance: float = 100.0

var _material: StandardMaterial3D
var _resaltados: Dictionary = {}  # Node -> Array de GeometryInstance3D
var _tiempo: float = 0.0


func _ready() -> void:
	# Capa de brillo aditivo: suma un poco de luz encima del objeto sin tapar su textura
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = Color(color_brillo, intensidad_min)


func _physics_process(_delta: float) -> void:
	var apuntados: Dictionary = {}

	var cam: Camera3D = get_viewport().get_camera_3d()
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	var pm_activo: bool = pm != null and (not (pm is CanvasLayer) or (pm as CanvasLayer).visible)

	if cam != null and pm_activo:
		for nombre in ["pointer_p1", "pointer_p2"]:
			var puntero: Variant = pm.get(nombre)
			if not (puntero is Control):
				continue
			var ctrl: Control = puntero
			if not ctrl.is_visible_in_tree():
				continue
			var interactuable: Node = _interactuable_apuntado(cam, ctrl.position + ctrl.size * 0.5)
			if interactuable != null:
				apuntados[interactuable] = true

	# Quitar el brillo a los que ya no se apuntan
	for nodo in _resaltados.keys():
		if not is_instance_valid(nodo) or not apuntados.has(nodo):
			_quitar_brillo(nodo)
	# Dar brillo a los nuevos
	for nodo in apuntados.keys():
		if not _resaltados.has(nodo):
			_poner_brillo(nodo)


func _process(delta: float) -> void:
	if _resaltados.is_empty():
		return
	# Pulso suave de la intensidad
	_tiempo += delta * velocidad_pulso
	var k: float = (sin(_tiempo) + 1.0) * 0.5
	_material.albedo_color = Color(color_brillo, lerpf(intensidad_min, intensidad_max, k))


func _interactuable_apuntado(cam: Camera3D, pantalla: Vector2) -> Node:
	var desde: Vector3 = cam.project_ray_origin(pantalla)
	var hasta: Vector3 = desde + cam.project_ray_normal(pantalla) * alcance
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, mascara_colision)
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = true
	var resultado: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return null

	# Sube por el árbol hasta encontrar el nodo marcado como interactuable
	var nodo: Node = resultado["collider"] as Node
	while nodo != null and not nodo.is_in_group(GRUPO):
		nodo = nodo.get_parent()
	if nodo == null:
		return null
	# Si el objeto dice que ahora no se puede usar, no brilla
	if nodo.has_method("puede_interactuar") and not nodo.call("puede_interactuar"):
		return null
	return nodo


func _poner_brillo(raiz: Node) -> void:
	var geometrias: Array = []
	_recolectar_geometrias(raiz, geometrias)
	for g in geometrias:
		(g as GeometryInstance3D).material_overlay = _material
	_resaltados[raiz] = geometrias


# Sin tipo en el parámetro: la llave u otros objetos pueden haberse liberado ya
func _quitar_brillo(raiz: Variant) -> void:
	var geometrias: Array = _resaltados.get(raiz, [])
	for g in geometrias:
		if is_instance_valid(g):
			(g as GeometryInstance3D).material_overlay = null
	_resaltados.erase(raiz)


func _recolectar_geometrias(nodo: Node, salida: Array) -> void:
	if nodo is GeometryInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_recolectar_geometrias(hijo, salida)


func _exit_tree() -> void:
	for nodo in _resaltados.keys():
		_quitar_brillo(nodo)
