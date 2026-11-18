extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var initial := int(Game.profile["money"])
	var first := int(round(200.0 * Game.diff_pay()))
	var second := int(round(100.0 * Game.diff_pay()))
	Game.add_money(200)
	Game.add_money(100)
	Game.add_money(-10)
	var ok := int(Game.profile["money"]) == initial - 10
	ok = ok and Game.profile["pending_money_rewards"] == [first, second]
	SaveSystem.save_game("reward_probe")
	Game.profile = Game.default_profile()
	ok = ok and SaveSystem.load_game("reward_probe")
	await get_tree().process_frame
	await get_tree().process_frame
	ok = ok and MoneyReward.overlay != null
	ok = ok and MoneyReward.amount.text == "+%d" % first
	MoneyReward._collect()
	MoneyReward._collect() # double tap cannot pay twice
	ok = ok and int(Game.profile["money"]) == initial - 10 + first
	await get_tree().create_timer(0.8).timeout
	ok = ok and MoneyReward.overlay != null and MoneyReward.amount.text == "+%d" % second
	MoneyReward._collect()
	ok = ok and int(Game.profile["money"]) == initial - 10 + first + second
	ok = ok and Game.profile["pending_money_rewards"].is_empty()
	await get_tree().create_timer(0.8).timeout
	ok = ok and MoneyReward.overlay == null
	SaveSystem.delete_save("reward_probe")
	print("MONEY_REWARD_OK=", ok)
	get_tree().quit(0 if ok else 1)
