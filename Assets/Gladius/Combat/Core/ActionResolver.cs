using System.Collections.Generic;
using Gladius.Combat.Results;
using Gladius.Combat.Systems;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;

namespace Gladius.Combat.Core
{
    public sealed class ActionResolver
    {
        private readonly Dictionary<string, SkillDefinition> _skills;
        private readonly DamageSystem _damageSystem;
        private readonly HitChanceSystem _hitChanceSystem;
        private readonly StatusSystem _statusSystem;
        private readonly StaminaSystem _staminaSystem;
        private readonly CombatControlsDefinition _controls;
        private readonly IRngService _rngService;

        public ActionResolver(
            SkillDefinition[] skills,
            CombatControlsDefinition controls,
            DamageSystem damageSystem,
            HitChanceSystem hitChanceSystem,
            StatusSystem statusSystem,
            StaminaSystem staminaSystem,
            IRngService rngService)
        {
            _controls = controls;
            _damageSystem = damageSystem;
            _hitChanceSystem = hitChanceSystem;
            _statusSystem = statusSystem;
            _staminaSystem = staminaSystem;
            _rngService = rngService;
            _skills = new Dictionary<string, SkillDefinition>();
            foreach (var skill in skills)
            {
                _skills[skill.Id] = skill;
            }
        }

        public IReadOnlyList<SkillDefinition> GetLegalSkills(GladiatorRuntimeState actor)
        {
            var legal = new List<SkillDefinition>();
            foreach (var skill in _skills.Values)
            {
                if (skill.UsableBy != "ANY" && skill.UsableBy != actor.ClassId)
                {
                    continue;
                }

                if (actor.Cooldowns.TryGetValue(skill.Id, out var cooldown) && cooldown > 0)
                {
                    continue;
                }

                if (actor.CurrentStamina < skill.StaCost)
                {
                    continue;
                }

                legal.Add(skill);
            }

            return legal;
        }

        public AttackResolutionResult Resolve(GladiatorRuntimeState attacker, GladiatorRuntimeState defender, string skillId)
        {
            var skill = _skills[skillId];
            if (!_staminaSystem.HasEnough(attacker, skill.StaCost))
            {
                return AttackResolutionResult.StaminaBlocked;
            }

            attacker.TempDefBonus = 0;
            _staminaSystem.Spend(attacker, skill.StaCost);

            if (skillId == "RECOVER")
            {
                _staminaSystem.ApplyRecover(attacker);
                return new AttackResolutionResult(AttackResolutionType.Hit, skill.StaCost, attacker.CurrentStamina, default, default, defender.CurrentHp, defender.CurrentHp, skillId, false, null);
            }

            if (skillId == "DEFEND")
            {
                attacker.TempDefBonus += _controls.DefendBonusDef;
                return new AttackResolutionResult(AttackResolutionType.Hit, skill.StaCost, attacker.CurrentStamina, default, default, defender.CurrentHp, defender.CurrentHp, skillId, false, null);
            }

            var conditionalHitMod = GetConditionalHitMod(skillId, attacker);
            var hitChance = _hitChanceSystem.Resolve(attacker, defender, skill, conditionalHitMod, _rngService);
            if (!hitChance.DidHit)
            {
                return new AttackResolutionResult(AttackResolutionType.Miss, skill.StaCost, attacker.CurrentStamina, hitChance, default, defender.CurrentHp, defender.CurrentHp, skillId, false, null);
            }

            var isCrit = _damageSystem.IsCritical(attacker, skill, attacker.TotalCritModPct, _rngService);
            var before = defender.CurrentHp;
            var damage = _damageSystem.Calculate(attacker, defender, skill, isCrit);
            defender.CurrentHp -= damage.FinalDamage;
            if (defender.CurrentHp < 0)
            {
                defender.CurrentHp = 0;
            }

            var appliedStatus = string.Empty;
            if (!string.IsNullOrEmpty(skill.ApplyStatusId))
            {
                _statusSystem.Apply(defender, skill.ApplyStatusId, skill.StatusTurns);
                appliedStatus = skill.ApplyStatusId;
            }

            if (skill.CooldownTurns > 0)
            {
                attacker.Cooldowns[skill.Id] = skill.CooldownTurns;
            }

            return new AttackResolutionResult(AttackResolutionType.Hit, skill.StaCost, attacker.CurrentStamina, hitChance, damage, before, defender.CurrentHp, skillId, isCrit, appliedStatus);
        }

        public void StartTurn(GladiatorRuntimeState actor)
        {
            _staminaSystem.StartTurnRegen(actor, _statusSystem.GetStaRegenMod(actor));
            UpdateExhausted(actor);
            ReduceCooldowns(actor);
        }

        public bool ShouldSkipTurn(GladiatorRuntimeState actor) => _statusSystem.HasSkipTurnStatus(actor);

        public int EndTurn(GladiatorRuntimeState actor)
        {
            var dot = _statusSystem.ApplyDotDamage(actor);
            _statusSystem.TickEndTurn(actor);
            UpdateExhausted(actor);
            return dot;
        }

        private void ReduceCooldowns(GladiatorRuntimeState actor)
        {
            var keys = new List<string>(actor.Cooldowns.Keys);
            foreach (var key in keys)
            {
                actor.Cooldowns[key]--;
                if (actor.Cooldowns[key] <= 0)
                {
                    actor.Cooldowns.Remove(key);
                }
            }
        }

        private void UpdateExhausted(GladiatorRuntimeState actor)
        {
            if (actor.CurrentStamina == 0)
            {
                _statusSystem.Apply(actor, "EXHAUSTED", 1);
            }
        }

        private static float GetConditionalHitMod(string skillId, GladiatorRuntimeState attacker)
        {
            if (skillId == "NET_THROW")
            {
                return attacker.TotalHitModPct;
            }

            return 0f;
        }
    }
}
