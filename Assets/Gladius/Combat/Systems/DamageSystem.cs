using Gladius.Combat.Results;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class DamageSystem
    {
        private readonly int _minDamage;

        public DamageSystem(CombatControlsDefinition controls)
        {
            _minDamage = controls.MinDamage;
        }

        public DamageResult Calculate(GladiatorRuntimeState attacker, GladiatorRuntimeState defender)
        {
            var raw = attacker.Attack - defender.Defense;
            var final = raw < _minDamage ? _minDamage : raw;
            return new DamageResult(raw, _minDamage, final);
        }
    }
}
