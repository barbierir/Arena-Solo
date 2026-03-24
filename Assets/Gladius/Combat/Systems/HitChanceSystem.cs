using Gladius.Combat.Results;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;

namespace Gladius.Combat.Systems
{
    public sealed class HitChanceSystem
    {
        private readonly float _baseHitChance;
        private readonly float _hitDeltaPerPoint;
        private readonly float _minHitChance;
        private readonly float _maxHitChance;

        public HitChanceSystem(CombatControlsDefinition controls)
        {
            _baseHitChance = controls.BaseHitChance;
            _hitDeltaPerPoint = controls.HitDeltaPerPoint;
            _minHitChance = controls.MinHitChance;
            _maxHitChance = controls.MaxHitChance;
        }

        public HitChanceResult Resolve(GladiatorRuntimeState attacker, GladiatorRuntimeState defender, IRngService rngService)
        {
            var delta = (attacker.Accuracy - defender.Evasion) * _hitDeltaPerPoint;
            var unclampedChance = _baseHitChance + delta;
            var probability = Clamp(unclampedChance, _minHitChance, _maxHitChance);
            var roll = rngService.NextDouble();
            var didHit = roll <= probability;
            return new HitChanceResult(probability, roll, didHit);
        }

        private static double Clamp(double value, double min, double max)
        {
            if (value < min)
            {
                return min;
            }

            if (value > max)
            {
                return max;
            }

            return value;
        }
    }
}
