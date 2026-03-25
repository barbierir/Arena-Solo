from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class Definitions:
    classes: dict[str, dict[str, Any]]
    builds: dict[str, dict[str, Any]]
    equipment: dict[str, dict[str, Any]]
    skills: dict[str, dict[str, Any]]
    status_effects: dict[str, dict[str, Any]]
    combat_controls: dict[str, Any]


@dataclass(frozen=True)
class BuildStats:
    max_hp: int
    max_sta: int
    atk: int
    defense: int
    spd: int
    skl: int
    total_hit_mod_pct: float
    total_crit_mod_pct: float


@dataclass
class RuntimeStatus:
    status_id: str
    remaining_turns: int
    applied_by_skill_id: str


@dataclass
class CombatantState:
    combatant_id: str
    build_id: str
    class_id: str
    display_name: str
    max_hp: int
    max_sta: int
    current_hp: int
    current_sta: int
    base_atk: int
    base_def: int
    base_spd: int
    base_skl: int
    total_hit_mod_pct: float
    total_crit_mod_pct: float
    temporary_defense_bonus: int = 0
    cooldowns: dict[str, int] = field(default_factory=dict)
    active_statuses: list[RuntimeStatus] = field(default_factory=list)

    def is_alive(self) -> bool:
        return self.current_hp > 0

    def has_status(self, status_id: str) -> bool:
        return any(s.status_id == status_id for s in self.active_statuses)

    def status_mod(self, stat_key: str, status_defs: dict[str, dict[str, Any]]) -> int:
        return sum(int(status_defs.get(s.status_id, {}).get(stat_key, 0)) for s in self.active_statuses)

    def effective_atk(self, status_defs: dict[str, dict[str, Any]]) -> int:
        return self.base_atk + self.status_mod("atk_mod", status_defs)

    def effective_def(self, status_defs: dict[str, dict[str, Any]]) -> int:
        return self.base_def + self.temporary_defense_bonus + self.status_mod("def_mod", status_defs)

    def effective_spd(self, status_defs: dict[str, dict[str, Any]]) -> int:
        return self.base_spd + self.status_mod("spd_mod", status_defs)

    def effective_skl(self) -> int:
        return self.base_skl


@dataclass
class CombatRuntime:
    attacker_build_id: str
    defender_build_id: str
    combatant_states: dict[str, CombatantState]
    turn_index: int = 0
    result_state: str = "PENDING"
    winner_combatant_id: str = ""
    current_actor_id: str = ""
    next_actor_id: str = ""
    combat_log: list[str] = field(default_factory=list)
    combat_events: list[dict[str, Any]] = field(default_factory=list)

    ATTACKER_SIDE_ID = "A"
    DEFENDER_SIDE_ID = "B"

    def append_log(self, msg: str) -> None:
        self.combat_log.append(msg)

    def append_event(self, event_type: str, payload: dict[str, Any]) -> None:
        event = {"type": event_type, "turn_index": self.turn_index}
        event.update(payload)
        self.combat_events.append(event)

    def attacker_state(self) -> CombatantState:
        return self.combatant_states[self.ATTACKER_SIDE_ID]

    def defender_state(self) -> CombatantState:
        return self.combatant_states[self.DEFENDER_SIDE_ID]

    def other_side_id(self, side_id: str) -> str:
        return self.DEFENDER_SIDE_ID if side_id == self.ATTACKER_SIDE_ID else self.ATTACKER_SIDE_ID
