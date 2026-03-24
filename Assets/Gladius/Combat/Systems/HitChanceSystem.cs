using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

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

        public double Calculate(GladiatorRuntimeState attacker, GladiatorRuntimeState defender)
        {
            var delta = (attacker.Accuracy - defender.Evasion) * _hitDeltaPerPoint;
            var chance = _baseHitChance + delta;

            if (chance < _minHitChance)
            {
                return _minHitChance;
            }

            if (chance > _maxHitChance)
            {
                return _maxHitChance;
            }

            return chance;
        }
    }
}
