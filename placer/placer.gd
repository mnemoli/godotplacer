@tool
extends EditorPlugin

var dock
var painting = false
var resource
var current_item
var temp_object_mat
var tree
var placing = false
var parent_node

func _enter_tree():
	print("Loading placer")
	dock = preload("res://addons/placer/resources/paintbutton.tscn").instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, dock)
	dock.get_node("Button").connect("pressed", toggle_painting)
	var vsplit = get_editor_interface().get_file_system_dock().get_child(3)
	for c in vsplit.get_children():
		if c is Tree:
			tree = c
			tree.connect("cell_selected", file_picked)
			break
	temp_object_mat = preload("res://addons/placer/resources/tempobjectmat.tres")
	change_parent_node()
	get_editor_interface().get_selection().connect("selection_changed", change_parent_node)
	
func change_parent_node():
	var parent_nodes = get_editor_interface().get_selection().get_selected_nodes()
	if !parent_nodes.is_empty():
		parent_node = parent_nodes[0]
	else:
		parent_node = get_editor_interface().get_edited_scene_root()
	print(parent_node)

func _exit_tree():
	print("Exiting placer")
	if current_item != null:
		current_item.free()
	if dock != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dock)
		dock.free()

func toggle_painting():
	painting = !painting
	if !painting:
		print("Painting toggled off")
		current_item.free()
		(dock.get_node("Button") as Button).button_pressed = false
	else:
		print("Painting toggled on")
		set_up_temp_object()
		(dock.get_node("Button") as Button).button_pressed = true

func _forward_3d_gui_input(camera, event):
	if !painting or !current_item:
		return false
	if event is InputEventMouseMotion:
		if !placing:
			var ray_origin = camera.project_ray_origin(event.position)
			var ray_dir = camera.project_ray_normal(event.position)
			var ray_distance = camera.far
			var space_state =  get_viewport().world_3d.direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
					ray_origin, ray_origin + ray_dir * ray_distance
			)
			var hit = space_state.intersect_ray(query)
			if !hit.is_empty():
				current_item.global_transform.origin = hit.position
			return false
		else:
			current_item.rotate_object_local(Vector3(0,1,0), event.relative.x / 10)
			return true
			
	elif event is InputEventMouseButton and event.pressed == true and event.button_index == MOUSE_BUTTON_LEFT:
		placing = true
	elif event is InputEventMouseButton and event.pressed == false and event.button_index == MOUSE_BUTTON_LEFT:
		placing = false
		var undo_redo = get_undo_redo()
		undo_redo.create_action("Add object", UndoRedo.MERGE_DISABLE, parent_node)
		var new_item = resource.instantiate()
		undo_redo.add_do_method(self, "redo_paint", new_item, current_item.global_transform, parent_node)
		undo_redo.add_do_reference(new_item)
		undo_redo.add_undo_method(parent_node, "remove_child", new_item)
		undo_redo.commit_action()
		return true
	elif event is InputEventMouse and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if Input.is_key_pressed(KEY_SHIFT):
			return false
		current_item.scale = current_item.scale * 0.9
		return true
	elif event is InputEventMouse and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if Input.is_key_pressed(KEY_SHIFT):
			return false
		current_item.scale = current_item.scale * 1.1
		return true
	return false
	

func _handles(object):
	return true

func file_picked():
	print("New file picked")
	if current_item != null:
		current_item.free()
	if !painting:
		return
	set_up_temp_object()
	
func set_up_temp_object():
	# get_editor_interface().get_current_path() returns the wrong path at this point
	# i.e. the previously selected node
	# So we must get the file tree selected item instead
	var path = tree.get_selected().get_metadata(0)
	resource = load(path)
	current_item = add_temp_item(resource)
	current_item.set_name("TEMPORARY OBJECT")

func add_temp_item(resource):
	var new_item = resource.instantiate()
	get_editor_interface().get_edited_scene_root().add_child(new_item)
	if new_item is MeshInstance3D:
		new_item.material_override = temp_object_mat
	else:
		for c in new_item.get_children():
			if c is MeshInstance3D:
				c.material_override = temp_object_mat
	return new_item

func redo_paint(new_item, transform, parent_node):
	if parent_node == null:
		parent_node = get_editor_interface().get_edited_scene_root()
	parent_node.add_child(new_item)
	new_item.owner = get_editor_interface().get_edited_scene_root()
	new_item.global_transform.origin = transform.origin
	new_item.global_transform.basis = transform.basis
	
