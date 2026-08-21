extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const SchemaValidator = preload("res://scripts/v2/content/v2_schema_validator.gd")

var t := Runner.new()

func _initialize() -> void:
	var invalid_documents := {
		"characters": {"assault": {
			"ability_id": "missing_ability",
			"passive_id": "missing_passive",
			"module_ids": ["missing_module"]
		}},
		"abilities": {},
		"modules": {},
		"missions": {"ch1_m1": {"dialogue_ids": ["missing_dialogue"]}},
		"dialogues": {}
	}
	var schema_errors: Array[String] = SchemaValidator.validate_all(invalid_documents)
	t.check(not schema_errors.is_empty(), "缺失引用被模式校验拒绝")
	t.check(str(schema_errors).contains("missing_ability"), "错误包含具体缺失 ID")
	t.finish(self)
