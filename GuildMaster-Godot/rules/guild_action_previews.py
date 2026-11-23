"""Private quotes built with the same payment rules used during actions."""

from itertools import combinations, permutations

from guild_content import ACHIEVEMENTS
from guild_engine import _zh


def _budget(player):
    return dict(player, tiles=list(player['tiles']))


def achievement_previews(engine, player):
    result = {}
    for scope, ids in (('public', engine.state['public_achievements']),
                       ('private', player['achievements'])):
        offers = result[scope] = {}
        for aid in ids:
            card = ACHIEVEMENTS.get(aid)
            if card is None:
                continue
            cap = (max(0, card.get('price', 0)) + 4) // 5 if card.get('can_trans') else 0
            quotes = offers[aid] = []
            for strength in range(1 if card.get('solo') else cap + 1):
                action = dict(id=aid, public=scope == 'public', strength=strength)
                try:
                    payments = engine._achievement_payment(player, action)
                    budget = _budget(player)
                    for costs in payments:
                        engine._pay(budget, costs, preview=True)
                    quotes.append({
                        'strength': payments[0]['strength'],
                        'gold': player['gold'] - budget['gold'],
                    })
                except ValueError as exc:
                    quotes.append({'error': _zh(str(exc))})
    return result


def development_preview(engine, player):
    slots = engine.rules['development_slots']
    festival_caps = engine.DEVELOPMENT_FESTIVAL_CAPS
    paid = [key for key in slots if key in festival_caps]
    other = [key for key in slots if key not in festival_caps]
    available = [key for key in slots if key not in player['developed']]
    modes = {'standard': {}, 'festival': {}}
    tokens = player.get('festival_tokens', 0)
    for count in range(1, min(len(available), 5 - player['affection']) + 1):
        for choice in combinations(available, count):
            ordered = [key for key in paid if key in choice]
            rest = [key for key in other if key in choice]
            for kind, orders in (('standard', [ordered]), ('festival', permutations(ordered))):
                if kind == 'festival' and not tokens:
                    continue
                for order in orders:
                    selected = list(order) + rest
                    spend = {}
                    if kind == 'festival':
                        remaining = tokens
                        for key in order:
                            amount = min(remaining, festival_caps[key])
                            if amount:
                                spend[key] = amount
                                remaining -= amount
                    quote = {}
                    try:
                        credits, costs = engine._development_payment(
                            player, count, dict(slots=selected, festival=spend))
                        budget = _budget(player)
                        if credits:
                            engine._credit_festival(budget, credits)
                        engine._pay(budget, costs, preview=True)
                        quote['festival'] = credits
                        quote['costs'] = {key: player[key] - budget[key]
                                          for key in ('gold', 'strength', 'pot')
                                          if player[key] > budget[key]}
                        if len(player['tiles']) > len(budget['tiles']):
                            quote['costs']['tiles'] = len(player['tiles']) - len(budget['tiles'])
                    except ValueError as exc:
                        if count != 1:
                            continue
                        quote['error'] = _zh(str(exc))
                    modes[kind][','.join(selected)] = quote
    return dict(modes, paid=paid, other=other)
