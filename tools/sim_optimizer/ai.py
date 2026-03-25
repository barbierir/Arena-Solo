from __future__ import annotations

from .models import CombatantState


def choose_action(actor: CombatantState, target: CombatantState) -> str:
    if actor.class_id == "SECUTOR":
        return choose_secutor_action(actor, target)
    if actor.current_sta <= 2:
        return "RECOVER"
    if actor.cooldowns.get("NET_THROW", 0) <= 0 and actor.current_sta >= 3 and not target.has_status("ENTANGLED"):
        return "NET_THROW"
    if actor.current_sta >= 2:
        return "BASIC_ATTACK"
    return "RECOVER"


def choose_secutor_action(actor: CombatantState, target: CombatantState) -> str:
    if actor.current_sta <= 2:
        return "RECOVER"
    shield_bash_ready = actor.cooldowns.get("SHIELD_BASH", 0) <= 0 and actor.current_sta >= 2
    if shield_bash_ready and not target.has_status("STUNNED"):
        return "SHIELD_BASH"
    if actor.current_sta >= 2:
        return "BASIC_ATTACK"
    return "RECOVER"
