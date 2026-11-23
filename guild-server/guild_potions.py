"""秘药行动的共享规则入口。

服务端各条路径（正常行动、卡牌效果、行动提示、界面状态）都在这里判断
「这个秘药格现在能不能用」，避免客户端/服务端各写一套条件。
"""
from guild_content import POTIONS


def funds(player):
    """可用于支付秘药的资源；霍伦黑版可把迷宫板块当秘药。"""
    value = int(player.get("pot", 0))
    if player.get("hero") == "horn_black":
        value += len(player.get("tiles", []))
    return value


def slot_error(engine, player, key, ignore_slot=False):
    if not isinstance(key, str) or key not in POTIONS:
        return "该秘药格目前不可用。"
    if ignore_slot:
        return ""
    if key in engine.state.get("potions_used", []):
        return "该秘药格本轮已使用。"
    if key in engine.state.get("potions_disabled", []):
        return "该秘药格当前人数不开放。"
    return ""


def target_error(engine, player, key):
    """检查秘药需要的目标；返回中文错误，正常返回空字符串。"""
    potion = POTIONS[key]
    effect = potion.get("effect", {})
    steps = effect.get("steps", [])
    build_step = next((step for step in steps if step.get("op") == "build"), None)
    build_needed = key == "build" or effect.get("build") or build_step is not None
    if build_needed:
        camps = [cell for cell in engine.state.get("board", [])
                 if cell.get("owner") == player["id"] and not cell.get("base")]
        if not camps:
            return "没有可以据点化的营地，秘药未消耗。"
        if key == "build" or effect.get("build"):
            base_cost = engine.rules["build_cost"]
            if not any(engine._affordable(player, {"gold": max(0, engine.build_cost(player["id"], cell["id"]) - base_cost)})
                       for cell in camps):
                return "据点化追加费用全部无法支付，秘药未消耗。"
    free_step = next((step for step in steps if step.get("op") == "play" and step.get("free")), None)
    if key == "free_card" or effect.get("free_card"):
        # 灵感药水只免金币，不要求玩家先付得起原价。
        free_step = free_step or {"free": True}
    if free_step is not None:
        nested = getattr(engine, "_can_nested_play", None)
        if nested is None:
            if not player.get("hand", []):
                return "没有可以免费打出的事件卡，秘药未消耗。"
        else:
            rule = free_step.get("filter", {})
            playable = False
            for card in set(player.get("hand", [])):
                data = engine.cards[card]
                if not engine._card_filter(data, rule):
                    continue
                if not engine._requirements(player, data.get("requirements", {}), True):
                    continue
                if nested(player, card, free_step):
                    playable = True
                    break
            if not playable:
                return "没有可以免费打出的事件卡，秘药未消耗。"
    return ""


def use_error(engine, player, action):
    """执行秘药行动前的完整校验，返回错误文案；空字符串表示可以执行。"""
    key = action.get("option")
    error = slot_error(engine, player, key, bool(action.get("_ignore_slot")))
    if error:
        return error
    potion = POTIONS[key]
    if funds(player) < int(potion.get("cost", 0)):
        return "秘药不足，秘药未消耗。"
    return target_error(engine, player, key)


def available(engine, player, key, ignore_slot=False):
    return not slot_error(engine, player, key, ignore_slot) and not target_error(engine, player, key) \
        and funds(player) >= int(POTIONS[key].get("cost", 0))


def potion_state(engine, player, key):
    """给界面使用的状态文案；与真正执行时的校验顺序保持一致。"""
    if key not in POTIONS:
        return "不可用"
    if key in engine.state.get("potions_disabled", []):
        return "未开放"
    if key in engine.state.get("potions_used", []):
        return "本轮已用"
    if player.get("withdrawn") or player.get("passed"):
        return "本季闭店"
    state = engine.state
    players = state.get("players", [])
    turn = state.get("turn", 0)
    if (state.get("phase") not in ("action", "final") or state.get("pending")
            or not isinstance(turn, int) or turn < 0 or turn >= len(players)
            or players[turn].get("id") != player.get("id")):
        return "等待行动"
    if funds(player) < int(POTIONS[key].get("cost", 0)):
        return "数量不足"
    error = target_error(engine, player, key)
    if error:
        if "没有可以据点化" in error:
            return "无可据点化营地"
        if "追加费用" in error:
            return "追加费用不足"
        if "免费打出" in error:
            return "无可用事件卡"
        return "不可用"
    return "可用"
