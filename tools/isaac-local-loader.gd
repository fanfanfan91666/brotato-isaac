extends "res://addons/mod_loader/mod_loader.gd"

# Steam builds only scan subscribed Workshop folders by default. Preserve that
# native path and additionally support ordinary local ZIPs beside Brotato.exe.
func _load_mod_zips() -> Dictionary:
    var result = ._load_mod_zips()
    var local_folder = OS.get_executable_path().get_base_dir().plus_file("mods")
    var local_mods = _ModLoaderFile.load_zips_in_folder(local_folder)
    result.merge(local_mods)
    return result
