"""情报收集结束后，选择看板娘的白面或黑面。

流程：房间选人物（不分黑白）→ 开局轮抽（若启用）→ 情报收集 →
选择人物对应的白/黑面 → 公会行动。
选面前用两版中较低的开局资源；选面后补足差额，并发放该面的
初始抽牌、标签、私有牌堆与角色专属开场效果。
"""
from guild_content import CHARACTERS, HEROES


def choose(engine, player, action):
    state = engine.state
    if state.get('phase') != 'face':
        raise ValueError('当前不能选择看板娘的白面或黑面。')
    if player.get('face_chosen'):
        raise ValueError('你已经选择过看板娘的面。')
    character = player.get('hero_character', '')
    variant = str(action.get('variant', ''))
    hero = CHARACTERS.get(character, {}).get('variants', {}).get(variant)
    if hero not in HEROES or not HEROES[hero].get('available', True):
        raise ValueError('请选择该看板娘的白面或黑面。')
    if engine.rules['options'].get('solo'):
        hero = HEROES.get(hero, {}).get('solo_replacement', hero)
    allocation = engine._hero_allocation(hero)
    provisional = player.get('face_resources', {})
    for key, value in allocation.items():
        player[key] = int(player.get(key, 0)) + int(value) - int(provisional.get(key, 0))
    player['hero'] = hero
    engine._apply_hero_draws(player)
    engine._setup_hero_extras(player)
    player['face_resources'] = allocation
    player['face_chosen'] = True
    engine._undo_checkpoint = None
    engine._log('%s选择了看板娘「%s」的%s面。' % (
        player['name'], HEROES[hero].get('name', hero),
        '黑' if HEROES[hero].get('variant') == 'black' else '白'), player)
    finish_if_ready(engine)


def finish_if_ready(engine):
    """所有在场玩家选完面后，执行角色专属开场效果并进入行动阶段。"""
    if engine.state.get('phase') != 'face':
        return False
    players = engine.state['players']
    if any(not p.get('face_chosen') and not p.get('withdrawn') for p in players):
        return False
    for p in players:
        if not p.get('withdrawn'):
            engine._apply_hero_initials(p)
    engine._drain_effects()
    engine.state['face_pending'] = False
    engine._begin_action_phase()
    return True


def auto_action(engine, player):
    character = player.get('hero_character', '')
    variants = CHARACTERS.get(character, {}).get('variants', {})
    for variant in ('white', 'black'):
        hero = variants.get(variant)
        if hero in HEROES and HEROES[hero].get('available', False):
            return dict(type='choose_face', variant=variant)
    raise ValueError('没有可用的看板娘黑白面。')


def redact(view, player_id, reveal=False):
    for player in view['players']:
        player['face_chosen'] = bool(player.get('face_chosen'))
        if player['id'] == player_id or reveal:
            continue
        player.pop('face_resources', None)
        if not player['face_chosen']:
            player['variant'] = ''
            player['hero'] = ''
