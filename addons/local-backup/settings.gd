extends Resource

enum RollingTimestamp { NONE, DATE, EPOCH }

const DIRECTORY_NAME := "application/local_backup/directory"
const DIRECTORY_DEFAULT := ""
const EXCLUDE_NAME := "application/local_backup/exclude"
const EXCLUDE_DEFAULT := PoolStringArray([".import", ".git"])
const ON_EXIT_NAME := "application/local_backup/on_exit"
const ON_EXIT_DEFAULT := true
const ROLLING_TIMESTAMP_NAME := "application/local_backup/rolling_timestamp"
const ROLLING_TIMESTAMP_DEFAULT := RollingTimestamp.NONE
const ROLLING_COUNT_NAME := "application/local_backup/rolling_count"
const ROLLING_COUNT_DEFAULT := 1


static func enum_to_hint(enumeration: Dictionary) -> String:
	return PoolStringArray(enumeration.keys()).join(",")


static func create_project_settings() -> void:
	create_project_setting(DIRECTORY_NAME, DIRECTORY_DEFAULT, PROPERTY_HINT_GLOBAL_DIR)
	create_project_setting(EXCLUDE_NAME, EXCLUDE_DEFAULT)
	create_project_setting(ON_EXIT_NAME, ON_EXIT_DEFAULT)
	create_project_setting(
		ROLLING_TIMESTAMP_NAME,
		ROLLING_TIMESTAMP_DEFAULT,
		PROPERTY_HINT_ENUM,
		enum_to_hint(RollingTimestamp)
	)


static func clear_project_settings() -> void:
	ProjectSettings.clear(DIRECTORY_NAME)
	ProjectSettings.clear(EXCLUDE_NAME)
	ProjectSettings.clear(ON_EXIT_NAME)
	ProjectSettings.clear(ROLLING_TIMESTAMP_NAME)


static func create_project_setting(
	name: String, default, hint: int = PROPERTY_HINT_NONE, hint_string := ""
) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default)

	ProjectSettings.set_initial_value(name, default)
	var info = {
		"name": name,
		"type": typeof(default),
		"hint": hint,
		"hint_string": hint_string,
	}
	ProjectSettings.add_property_info(info)


static func get_setting(name: String, default):
	if ProjectSettings.has_setting(name):
		return ProjectSettings.get_setting(name)
	return default


static func get_directory() -> String:
	return get_setting(DIRECTORY_NAME, DIRECTORY_DEFAULT)


static func get_application_name() -> String:
	return get_setting("application/config/name", "backup").http_escape()


static func has_directory() -> bool:
	return not get_directory().empty()


static func directory_exists() -> bool:
	var dir := Directory.new()
	return dir.dir_exists(get_directory())


static func is_directory_recursive() -> bool:
	return get_directory().begins_with(ProjectSettings.globalize_path("res://"))


static func generate_directory() -> String:
	return get_directory().plus_file(get_application_name() + generate_rolling_timestamp()).plus_file(
		""
	)


static func get_exclude() -> PoolStringArray:
	return get_setting(EXCLUDE_NAME, EXCLUDE_DEFAULT)


static func get_on_exit() -> bool:
	return get_setting(ON_EXIT_NAME, ON_EXIT_DEFAULT)


static func get_rolling_timestamp() -> int:
	return get_setting(ROLLING_TIMESTAMP_NAME, ROLLING_TIMESTAMP_DEFAULT)


static func generate_rolling_timestamp() -> String:
	match get_rolling_timestamp():
		RollingTimestamp.NONE:
			return ""
		RollingTimestamp.DATE:
			var date := OS.get_date()
			return "-%04d%02d%02d" % [date["year"], date["month"], date["day"]]
		RollingTimestamp.EPOCH:
			return "-{0}".format([OS.get_system_time_msecs])
	return ""


static func get_rolling_count() -> int:
	return get_setting(ROLLING_COUNT_NAME, ROLLING_COUNT_DEFAULT)
