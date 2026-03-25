from __future__ import annotations

import random
from dataclasses import replace
from typing import Any

from .ai import choose_action
from .loader import resolve_build_stats
from .models import CombatRuntime, CombatantState, Definitions, RuntimeStatus


class CombatEngine:
    def __init__(self, definitions: Definitions, seed: int, matchup_modifiers: dict[str, Any] | None = None):
        self.defs = definitions
        self.rng = random.Random(seed)
        self.matchup_modifiers = matchup_modifiers or {}

    def initialize_fight(self, attacker_build_id: str, defender_build_id: str) -> CombatRuntime:
        a = self._make_combatant_state(attacker_build_id, CombatRuntime.ATTACKER_SIDE_ID)
        b = self._make_combatant_state(defender_build_id, CombatRuntime.DEFENDER_SIDE_ID)
        self._apply_initial_hp_modifiers(a, b)
        runtime = CombatRuntime(
            attacker_build_id=attacker_build_id,
            defender_build_id=defender_build_id,
            combatant_states={CombatRuntime.ATTACKER_SIDE_ID: a, CombatRuntime.DEFENDER_SIDE_ID: b},
        )
        runtime.next_actor_id = self._resolve_first_actor(runtime)
        runtime.append_log(f"Encounter initialized: {attacker_build_id} vs {defender_build_id}")
        return runtime

    def _apply_initial_hp_modifiers(self, attacker: CombatantState, defender: CombatantState) -> None:
        attacker_bonus = int(self.matchup_modifiers.get("attacker_bonus_hp", 0))
        defender_bonus = int(self.matchup_modifiers.get("defender_bonus_hp", 0))
        both_bonus = int(self.matchup_modifiers.get("both_bonus_hp", 0))

        if attacker_bonus or both_bonus:
            attacker.max_hp += attacker_bonus + both_bonus
            attacker.current_hp = attacker.max_hp
        if defender_bonus or both_bonus:
            defender.max_hp += defender_bonus + both_bonus
            defender.current_hp = defender.max_hp

    def run_to_completion(self, runtime: CombatRuntime, max_turns: int = 64) -> CombatRuntime:
        for _ in range(max_turns):
            if runtime.result_state != "PENDING":
                break
            self.execute_turn(runtime)
        if runtime.result_state == "PENDING":
            runtime.result_state = "ABORTED"
            runtime.append_event("COMBAT_ENDED", {
                "terminal_condition": "MAX_TURNS_ABORT",
                "winner_build_id": "",
                "winner_combatant_id": "",
            })
        return runtime

    def execute_turn(self, runtime: CombatRuntime) -> None:
        runtime.turn_index += 1
        actor_id = runtime.next_actor_id or CombatRuntime.ATTACKER_SIDE_ID
        runtime.current_actor_id = actor_id
        runtime.next_actor_id = runtime.other_side_id(actor_id)
        actor = runtime.combatant_states[actor_id]
        target = runtime.combatant_states[runtime.other_side_id(actor_id)]

        controls = self.defs.combat_controls
        statuses = self.defs.status_effects

        actor.temporary_defense_bonus = 0
        regen = int(controls.get("base_stamina_regen", 2)) + actor.status_mod("sta_regen_mod", statuses)
        actor.current_sta = max(0, min(actor.max_sta, actor.current_sta + regen))
        self._update_exhausted(actor)
        self._tick_cooldowns(actor)
        runtime.append_event("TURN_TELEMETRY", {
            "phase": "START_OF_TURN",
            "actor_side_id": actor.combatant_id,
            "target_side_id": target.combatant_id,
            "actor_sta_after": actor.current_sta,
            "target_sta_after": target.current_sta,
            "actor_active_status_ids": [s.status_id for s in actor.active_statuses],
            "target_active_status_ids": [s.status_id for s in target.active_statuses],
        })

        if self._status_skip_turn(actor):
            self._tick_status_durations(actor)
            dot = self._apply_end_of_turn_dot(actor)
            self._resolve_victory(runtime)
            self._append_end_turn(runtime, actor, target, dot)
            return

        skill_id = choose_action(actor, target)
        skill = self.defs.skills.get(skill_id, self.defs.skills["BASIC_ATTACK"])
        if int(skill.get("sta_cost", 999)) > actor.current_sta:
            skill_id = "RECOVER"
            skill = self.defs.skills["RECOVER"]

        self._execute_action(runtime, actor, target, skill_id, skill)
        if runtime.result_state != "PENDING":
            self._append_end_turn(runtime, actor, target, 0)
            return

        self._tick_status_durations(actor)
        self._update_exhausted(actor)
        dot = self._apply_end_of_turn_dot(actor)
        self._resolve_victory(runtime)
        self._append_end_turn(runtime, actor, target, dot)

    def _make_combatant_state(self, build_id: str, side_id: str) -> CombatantState:
        build = self.defs.builds[build_id]
        stats = resolve_build_stats(self.defs, build_id)
        return CombatantState(
            combatant_id=side_id,
            build_id=build_id,
            class_id=build["class_id"],
            display_name=build.get("display_name", build_id),
            max_hp=stats.max_hp,
            max_sta=stats.max_sta,
            current_hp=stats.max_hp,
            current_sta=stats.max_sta,
            base_atk=stats.atk,
            base_def=stats.defense,
            base_spd=stats.spd,
            base_skl=stats.skl,
            total_hit_mod_pct=stats.total_hit_mod_pct,
            total_crit_mod_pct=stats.total_crit_mod_pct,
        )

    def _resolve_first_actor(self, runtime: CombatRuntime) -> str:
        a, b = runtime.attacker_state(), runtime.defender_state()
        if a.base_spd > b.base_spd:
            return "A"
        if b.base_spd > a.base_spd:
            return "B"
        return "A" if self.rng.random() <= 0.5 else "B"

    def _execute_action(self, runtime: CombatRuntime, actor: CombatantState, target: CombatantState, skill_id: str, skill: dict[str, Any]) -> None:
        controls = self.defs.combat_controls
        statuses = self.defs.status_effects

        sta_cost = int(skill.get("sta_cost", 0))
        actor.current_sta = max(0, actor.current_sta - sta_cost)
        self._update_exhausted(actor)

        if skill_id == "RECOVER":
            gain = int(controls.get("recover_bonus_stamina", 2))
            recover_multiplier = float(self.matchup_modifiers.get("recover_value_multiplier", 1.0))
            gain = max(0, round(gain * recover_multiplier))
            actor.current_sta = min(actor.max_sta, actor.current_sta + gain)
            runtime.append_event("ACTION_USED", self._action_payload(actor, target, skill_id, False, 0))
            return

        if skill_id == "DEFEND":
            actor.temporary_defense_bonus = int(controls.get("defend_bonus_def", 2))
            runtime.append_event("ACTION_USED", self._action_payload(actor, target, skill_id, False, 0))
            return

        hit_chance = self._calculate_hit(actor, target, skill, skill_id)
        hit_roll = self.rng.random()
        if hit_roll > hit_chance:
            runtime.append_event("ACTION_USED", self._action_payload(actor, target, skill_id, False, 0))
            self._set_cooldown(actor, skill_id, skill)
            return

        base_damage = self._calculate_base_damage(actor, target, skill)
        crit_chance = self._calculate_crit(actor, skill)
        is_crit = self.rng.random() <= crit_chance
        damage = round(base_damage * float(controls.get("crit_multiplier", 2.0))) if is_crit else base_damage
        damage_multiplier = float(self.matchup_modifiers.get("global_damage_multiplier", 1.0))
        damage = max(int(controls.get("min_damage", 1)), round(damage * damage_multiplier))
        target.current_hp = max(0, target.current_hp - damage)
        payload = self._action_payload(actor, target, skill_id, True, damage)
        payload["is_crit"] = is_crit
        runtime.append_event("ACTION_USED", payload)

        self._resolve_victory(runtime)
        if runtime.result_state != "PENDING":
            return

        status_id = str(skill.get("apply_status_id", ""))
        if status_id:
            self._apply_status(target, status_id, int(skill.get("status_turns", 0)), skill_id)
            runtime.append_event("STATUS_APPLIED", {
                "target_side_id": target.combatant_id,
                "target_build_id": target.build_id,
                "status_id": status_id,
                "source_skill_id": skill_id,
                "duration_turns": int(skill.get("status_turns", 0)),
            })
        self._set_cooldown(actor, skill_id, skill)

    def _action_payload(self, actor: CombatantState, target: CombatantState, skill_id: str, hit: bool, damage: int) -> dict[str, Any]:
        return {
            "actor_side_id": actor.combatant_id,
            "actor_build_id": actor.build_id,
            "target_side_id": target.combatant_id,
            "target_build_id": target.build_id,
            "skill_id": skill_id,
            "hit": hit,
            "damage": damage,
        }

    def _calculate_hit(self, actor: CombatantState, target: CombatantState, skill: dict[str, Any], skill_id: str) -> float:
        c = self.defs.combat_controls
        status_defs = self.defs.status_effects
        hit = float(c.get("base_hit_chance", 0.7))
        hit += (actor.effective_atk(status_defs) - target.effective_spd(status_defs)) * float(c.get("hit_delta_per_point", 0.02))
        hit += float(skill.get("accuracy_mod_pct", 0.0))
        if skill_id == "NET_THROW":
            build = self.defs.builds[actor.build_id]
            offhand = self.defs.equipment.get(build.get("offhand_item_id", ""), {})
            hit += float(offhand.get("hit_mod_pct", 0.0))
        if target.effective_spd(status_defs) - actor.effective_spd(status_defs) >= 5:
            hit -= float(c.get("dodge_bonus_if_defender_spd_lead_gte5", 0.15))
        return max(float(c.get("min_hit_chance", 0.1)), min(float(c.get("max_hit_chance", 0.95)), hit))

    def _calculate_crit(self, actor: CombatantState, skill: dict[str, Any]) -> float:
        c = self.defs.combat_controls
        crit = float(c.get("base_crit_chance", 0.05))
        crit += actor.effective_skl() * float(c.get("crit_per_skl", 0.01))
        crit += float(skill.get("crit_bonus_pct", 0.0)) + actor.total_crit_mod_pct
        return min(float(c.get("crit_chance_cap", 0.5)), crit)

    def _calculate_base_damage(self, actor: CombatantState, target: CombatantState, skill: dict[str, Any]) -> int:
        c = self.defs.combat_controls
        status_defs = self.defs.status_effects
        scaled_def = round(target.effective_def(status_defs) * float(c.get("defense_effectiveness", 1.0)))
        raw = actor.effective_atk(status_defs) + int(skill.get("flat_damage", 0)) - int(scaled_def)
        return max(int(c.get("min_damage", 1)), int(raw))

    def _status_skip_turn(self, actor: CombatantState) -> bool:
        defs = self.defs.status_effects
        return any(bool(defs.get(s.status_id, {}).get("skip_turn", False)) for s in actor.active_statuses)

    def _apply_status(self, target: CombatantState, status_id: str, turns: int, source_skill_id: str) -> None:
        if not status_id or turns <= 0:
            return
        defs = self.defs.status_effects
        stack_rule = str(defs.get(status_id, {}).get("stack_rule", "Refresh"))
        for idx, existing in enumerate(target.active_statuses):
            if existing.status_id != status_id:
                continue
            if stack_rule in {"Replace", "Refresh"}:
                target.active_statuses[idx] = replace(existing, remaining_turns=turns, applied_by_skill_id=source_skill_id)
                return
        target.active_statuses.append(RuntimeStatus(status_id, turns, source_skill_id))

    def _apply_end_of_turn_dot(self, actor: CombatantState) -> int:
        defs = self.defs.status_effects
        dot = sum(int(defs.get(s.status_id, {}).get("dot_damage", 0)) for s in actor.active_statuses)
        if dot > 0:
            actor.current_hp = max(0, actor.current_hp - dot)
        return dot

    def _tick_status_durations(self, actor: CombatantState) -> None:
        updated: list[RuntimeStatus] = []
        for s in actor.active_statuses:
            remain = s.remaining_turns - 1
            if remain > 0:
                updated.append(replace(s, remaining_turns=remain))
        actor.active_statuses = updated

    def _update_exhausted(self, actor: CombatantState) -> None:
        if actor.current_sta == 0:
            if not actor.has_status("EXHAUSTED"):
                actor.active_statuses.append(RuntimeStatus("EXHAUSTED", 1, "RUNTIME"))
            return
        actor.active_statuses = [s for s in actor.active_statuses if s.status_id != "EXHAUSTED"]

    def _tick_cooldowns(self, actor: CombatantState) -> None:
        actor.cooldowns = {k: v - 1 for k, v in actor.cooldowns.items() if int(v) - 1 > 0}

    def _set_cooldown(self, actor: CombatantState, skill_id: str, skill: dict[str, Any]) -> None:
        cd = int(skill.get("cooldown_turns", 0))
        if cd > 0:
            actor.cooldowns[skill_id] = cd

    def _resolve_victory(self, runtime: CombatRuntime) -> None:
        if runtime.result_state != "PENDING":
            return
        a, b = runtime.attacker_state(), runtime.defender_state()
        if not a.is_alive() and not b.is_alive():
            runtime.result_state = "DRAW"
            runtime.winner_combatant_id = ""
            runtime.append_event("COMBAT_ENDED", {"terminal_condition": "DOUBLE_KO", "winner_build_id": "", "winner_combatant_id": ""})
        elif not a.is_alive():
            runtime.result_state = "DEFEAT"
            runtime.winner_combatant_id = "B"
            runtime.append_event("COMBAT_ENDED", {"terminal_condition": "HP_ZERO", "winner_build_id": b.build_id, "winner_combatant_id": "B"})
        elif not b.is_alive():
            runtime.result_state = "VICTORY"
            runtime.winner_combatant_id = "A"
            runtime.append_event("COMBAT_ENDED", {"terminal_condition": "HP_ZERO", "winner_build_id": a.build_id, "winner_combatant_id": "A"})

    def _append_end_turn(self, runtime: CombatRuntime, actor: CombatantState, target: CombatantState, dot_damage: int) -> None:
        runtime.append_event("TURN_TELEMETRY", {
            "phase": "END_OF_TURN",
            "actor_side_id": actor.combatant_id,
            "actor_build_id": actor.build_id,
            "actor_hp_after": actor.current_hp,
            "actor_sta_after": actor.current_sta,
            "actor_active_status_ids": [s.status_id for s in actor.active_statuses],
            "target_side_id": target.combatant_id,
            "target_build_id": target.build_id,
            "target_hp_after": target.current_hp,
            "target_sta_after": target.current_sta,
            "target_active_status_ids": [s.status_id for s in target.active_statuses],
            "dot_damage_applied": dot_damage,
            "terminal_result_state": runtime.result_state,
        })
