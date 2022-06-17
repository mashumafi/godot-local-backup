tool
extends EditorPlugin

const BACKUPS := "Backups"
const Settings := preload("settings.gd")

var backups_popup_menu: BackupsPopupMenu


class CopyFile:
	var from: String
	var to: String

	func _init(from: String, to: String) -> void:
		self.from = from
		self.to = to

	func do_work() -> void:
		var dir := Directory.new()
		var rc := dir.make_dir_recursive(to.get_base_dir())
		if rc != OK:
			printerr("Could not create folder")
		rc = dir.copy(from, to)
		if rc != OK:
			printerr("Could not copy file")

		prints("Copied", from)


class RemoveFile:
	var path: String

	func _init(path: String) -> void:
		self.path = path

	func do_work() -> void:
		var dir := Directory.new()
		var rc := dir.remove(path)
		if OK == rc:
			prints("Removed", path)
		else:
			printerr("Could not remove rc:", rc, " path:", path)


class ReplaceFile:
	var from: String
	var to: String

	func _init(from: String, to: String) -> void:
		self.from = from
		self.to = to

	func read_all(path: String) -> PoolByteArray:
		var file := File.new()
		if OK != file.open(path, File.READ):
			return PoolByteArray()
		return file.get_buffer(file.get_len())

	func do_work() -> void:
		var src := read_all(from)
		var dst := read_all(to)
		if src.size() == dst.size():
			if src == dst:
				return

		var copy := CopyFile.new(from, to)
		copy.do_work()


func _notification(what):
	if what == NOTIFICATION_WM_QUIT_REQUEST and Engine.editor_hint and Settings.get_on_exit():
		backups_popup_menu.create_backup()


class BackupsPopupMenu:
	extends PopupMenu

	enum Backup { CREATE, OPEN }

	func _init() -> void:
		add_item("Create Backup", Backup.CREATE)
		add_item("Open Backup Folder", Backup.OPEN)

		connect("id_pressed", self, "_id_pressed")

	func _id_pressed(id: int) -> void:
		match id:
			Backup.CREATE:
				create_backup()
			Backup.OPEN:
				OS.shell_open("file://" + Settings.get_directory())

	func src_to_dest(src: String) -> String:
		return Settings.generate_directory().plus_file(src)

	func create_backup() -> void:
		prints("Creating backup at ", Settings.generate_directory())
		var start_time := OS.get_system_time_msecs()
		var exclude := set_from_array(Settings.get_exclude())

		var source := set_from_array(get_all_files("res://", exclude, "res://"))
		var target := set_from_array(
			get_all_files(Settings.generate_directory(), {}, Settings.generate_directory())
		)

		var added := diff(source, target)
		var removed := diff(target, source)
		var kept := intersect(source, target)
		var jobs := []
		for file in added:
			jobs.append(CopyFile.new(file, src_to_dest(file)))
		for file in removed:
			jobs.append(RemoveFile.new(src_to_dest(file)))
		for file in kept:
			jobs.append(ReplaceFile.new(file, src_to_dest(file)))
		while not jobs.empty():
			var job = jobs.front()
			jobs.pop_front()
			job.do_work()
		print("Added: ", added.size())
		print("Removed: ", removed.size())
		print("Kept: ", kept.size())
		print("Backup took %d milliseconds" % [OS.get_system_time_msecs() - start_time])

	func get_all_files(path: String, exclude: Dictionary, prefix: String) -> PoolStringArray:
		var files := PoolStringArray()
		var dir := Directory.new()
		if dir.open(path) == OK:
			dir.list_dir_begin(true)
			var file_name := dir.get_next()
			while file_name != "":
				if exclude.has(file_name):
					pass
				elif dir.current_is_dir():
					files += get_all_files(path.plus_file(file_name), exclude, prefix)
				else:
					files.append(path.plus_file(file_name).trim_prefix(prefix))
				file_name = dir.get_next()
		else:
			printerr("Invalid path: " + path)
		return files

	static func set_from_array(array: Array) -> Dictionary:
		var result := Dictionary()
		for key in array:
			result[key] = true
		return result

	static func union(left: Dictionary, right: Dictionary) -> Dictionary:
		return set_from_array(left.keys() + right.keys())

	static func intersect(left: Dictionary, right: Dictionary) -> Dictionary:
		var set := Dictionary()
		for key in left:
			if right.has(key):
				set[key] = true
		return set

	static func diff(left: Dictionary, right: Dictionary) -> Dictionary:
		var set := set_from_array(left.keys())
		for key in right.keys():
			set.erase(key)
		return set


func _enter_tree():
	Settings.create_project_settings()
	backups_popup_menu = BackupsPopupMenu.new()
	add_tool_submenu_item(BACKUPS, backups_popup_menu)


func _exit_tree():
	Settings.clear_project_settings()
	remove_tool_menu_item(BACKUPS)
	backups_popup_menu = null
