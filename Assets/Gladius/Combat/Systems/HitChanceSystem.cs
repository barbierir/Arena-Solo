using Gladius.Combat.Results;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;

namespace Gladius.Combat.Systems
{
    public sealed class HitChanceSystem
    {
        private readonly CombatControlsDefinition _controls;

        public HitChanceSystem(CombatControlsDefinition controls)
        {
            _controls = controls;
        }

        public HitChanceResult Resolve(GladiatorRuntimeState attacker, GladiatorRuntimeState defender, SkillDefinition skill, float conditionalHitModPct, IRngService rngService)
        {
            var dodgePenalty = defender.Spd - attacker.Spd >= 5 ? _controls.DodgeBonusIfDefenderSpdLeadGte5 : 0f;
            var unclamped = _controls.BaseHitChance
                            + (attacker.Atk - defender.Spd) * _controls.HitDeltaPerPoint
                            + skill.AccuracyModPct
                            + conditionalHitModPct
                            - dodgePenalty;
            var probability = Clamp(unclamped, _controls.MinHitChance, _controls.MaxHitChance);
            var roll = rngService.NextDouble();
            return new HitChanceResult(probability, roll, roll <= probability);
        }

        private static float Clamp(float value, float min, float max)
        {
            if (value < min) return min;
            if (value > max) return max;
            return value;
        }
    }
}
