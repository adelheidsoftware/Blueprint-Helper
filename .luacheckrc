std = "lua54"
max_line_length = 120

read_globals = { "ui", "id", "Event", "PersistentDB", "log", "prettyui" }

globals = { "PluginShutdown" }

ignore = { "212/self" }

files["tests"] = { max_line_length = false }

exclude_files = { "dist" }
