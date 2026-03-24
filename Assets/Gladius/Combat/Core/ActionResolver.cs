using Gladius.Combat.Systems;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;

namespace Gladius.Combat.Core
{
    public sealed class ActionResolver
    {
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

        public ResolutionResult ResolveBasicAttack(GladiatorRuntimeState actor, GladiatorRuntimeState target)
        {
            if (!_staminaSystem.HasEnough(actor, 1))
            {
                return ResolutionResult.StaminaBlocked;
            }

            _staminaSystem.Spend(actor, 1);
            var hitChance = _hitChanceSystem.Calculate(actor, target);
            var didHit = _rngService.NextDouble() <= hitChance;

            if (!didHit)
            {
                return ResolutionResult.Miss;
            }

            var damage = _damageSystem.Calculate(actor, target);
            target.CurrentHp = target.CurrentHp - damage;
            _statusSystem.Tick(target);
            return ResolutionResult.Hit;
        }
    }

    public enum ResolutionResult
    {
        StaminaBlocked,
        Miss,
        Hit
    }
}
