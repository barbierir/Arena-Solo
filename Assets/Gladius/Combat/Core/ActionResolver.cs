using Gladius.Combat.Results;
using Gladius.Combat.Systems;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;

namespace Gladius.Combat.Core
{
    public sealed class ActionResolver
    {
        private const int BasicAttackStaminaCost = 1;

        private readonly DamageSystem _damageSystem;
        private readonly HitChanceSystem _hitChanceSystem;
        private readonly StatusSystem _statusSystem;
        private readonly StaminaSystem _staminaSystem;
        private readonly IRngService _rngService;

        public ActionResolver(
            DamageSystem damageSystem,
            HitChanceSystem hitChanceSystem,
            StatusSystem statusSystem,
            StaminaSystem staminaSystem,
            IRngService rngService)
        {
            _damageSystem = damageSystem;
            _hitChanceSystem = hitChanceSystem;
            _statusSystem = statusSystem;
            _staminaSystem = staminaSystem;
            _rngService = rngService;
        }

        public AttackResolutionResult ResolveBasicAttack(GladiatorRuntimeState attacker, GladiatorRuntimeState defender)
        {
            if (!_staminaSystem.HasEnough(attacker, BasicAttackStaminaCost))
            {
                return AttackResolutionResult.StaminaBlocked;
            }

            _staminaSystem.Spend(attacker, BasicAttackStaminaCost);
            var hitChance = _hitChanceSystem.Resolve(attacker, defender, _rngService);

            if (!hitChance.DidHit)
            {
                return new AttackResolutionResult(
                    AttackResolutionType.Miss,
                    BasicAttackStaminaCost,
                    attacker.CurrentStamina,
                    hitChance,
                    default,
                    defender.CurrentHp,
                    defender.CurrentHp);
            }

            var targetHpBeforeDamage = defender.CurrentHp;
            var damage = _damageSystem.Calculate(attacker, defender);
            defender.CurrentHp -= damage.FinalDamage;
            _statusSystem.Tick(defender);

            return new AttackResolutionResult(
                AttackResolutionType.Hit,
                BasicAttackStaminaCost,
                attacker.CurrentStamina,
                hitChance,
                damage,
                targetHpBeforeDamage,
                defender.CurrentHp);
        }
    }
}
