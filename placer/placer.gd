tool
extends EditorPlugin

var dock
var painting = false
var resource
var current_item
var temp_object_mat
var tree

func _enter_tree():
	dock = preload("res://addons/placer/resources/paintbutton.tscn").instance()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, dock)
	dock.get_node("Button").connect("pressed", self, "toggle_painting")
	var vsplit = get_editor_interface().get_file_system_dock().get_child(3)
	for c in vsplit.get_children():
		if c is Tree:
			tree = c
			tree.connect("cell_selected", self, "file_picked")
			break
	temp_object_mat = preload("res://addons/placer/resources/tempobjectmat.tres")

func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, dock)
	dock.free()

func toggle_painting():
	painting = !painting
	if !painting:
		print("Painting toggled off")
		current_item.free()
	else:
		print("Painting toggled on")
		set_up_temp_object()

func forward_spatial_gui_input(camera, event):
	if !painting:
		return
	if event is InputEventMouseMotion:
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_dir = camera.project_ray_normal(event.position)
		var ray_distance = camera.far
		var space_state =  get_viewport().world.direct_space_state
		var hit = space_state.intersect_ray(ray_origin, ray_origin + ray_dir * ray_distance)
		if !hit.empty():
			current_item.transform.origin = hit.position
	elif event is InputEventMouseButton and event.pressed == true and event.button_index == BUTTON_LEFT:
		var undo_redo = get_undo_redo()
		undo_redo.create_action("Add object")
		var new_item = resource.instance()
		undo_redo.add_do_method(self, "redo_paint", new_item, current_item.transform)
		undo_redo.add_do_reference(new_item)
		undo_redo.add_undo_method(get_editor_interface().get_edited_scene_root(), "remove_child", new_item)
		undo_redo.commit_action()
	pass

func handles(object):
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
	var new_item = resource.instance()
	get_editor_interface().get_edited_scene_root().add_child(new_item)
	if new_item is MeshInstance:
		new_item.material_override = temp_object_mat
	else:
		for c in new_item.get_children():
			if c is MeshInstance:
				c.material_override = temp_object_mat
	return new_item

func redo_paint(new_item, transform):
	get_editor_interface().get_edited_scene_root().add_child(new_item)
	new_item.owner = get_editor_interface().get_edited_scene_root()
	new_item.transform.origin = transform.origin
	
