extends Node
class_name ProceduralWorld

func generate(width: int, height: int, seed: int = 0) -> Dictionary:
    return {
        "map": null,
        "colors": [],
        "area_info": null,
    }

func run_tests() -> Dictionary:
    return {
        "failed": 0,
        "total": 0,
        "log": "",
    }