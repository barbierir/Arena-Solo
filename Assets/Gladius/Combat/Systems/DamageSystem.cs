using Gladius.Combat.Results;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class DamageSystem
    {
        private readonly CombatControlsDefinition _controls;

        public DamageSystem(CombatControlsDefinition controls)
        {
            _controls = controls;
        }

        public DamageResult Calculate(GladiatorRuntimeState attacker, GladiatorRuntimeState defender, SkillDefinition skill, bool isCritical)
        {
            var rawBaseDamage = attacker.Atk + skill.FlatDamage - (defender.Def + defender.TempDefBonus);
            var baseDamage = rawBaseDamage < _controls.MinDamage ? _controls.MinDamage : rawBaseDamage;
            var finalDamage = isCritical ? (int)(baseDamage * _controls.CritMultiplier) : baseDamage;
            return new DamageResult(rawBaseDamage, _controls.MinDamage, finalDamage);
        }

        public bool IsCritical(GladiatorRuntimeState attacker, SkillDefinition skill, float conditionalCritMod, Gladius.Utilities.RNG.IRngService rngService)
        {
            var critChance = _controls.BaseCritChance + attacker.Skl * _controls.CritPerSkl + skill.CritBonusPct + conditionalCritMod;
            if (critChance > _controls.CritChanceCap)
            {
                critChance = _controls.CritChanceCap;
            }

            return rngService.NextDouble() <= critChance;
        }
    }
}
