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

        public int Calculate(GladiatorRuntimeState attacker, GladiatorRuntimeState defender)
        {
            var raw = attacker.Attack - defender.Defense;
            return raw < _minDamage ? _minDamage : raw;
        }
    }
}
