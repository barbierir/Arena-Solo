namespace Gladius.Combat.Results
{
    public readonly struct AttackResolutionResult
    {
        public AttackResolutionResult(
            AttackResolutionType type,
            int staminaCost,
            int staminaAfterSpend,
            HitChanceResult hitChance,
            DamageResult damage,
            int targetHpBefore,
            int targetHpAfter)
        {
            Type = type;
            StaminaCost = staminaCost;
            StaminaAfterSpend = staminaAfterSpend;
            HitChance = hitChance;
            Damage = damage;
            TargetHpBefore = targetHpBefore;
            TargetHpAfter = targetHpAfter;
        }

        public AttackResolutionType Type { get; }
        public int StaminaCost { get; }
        public int StaminaAfterSpend { get; }
        public HitChanceResult HitChance { get; }
        public DamageResult Damage { get; }
        public int TargetHpBefore { get; }
        public int TargetHpAfter { get; }

        public static AttackResolutionResult StaminaBlocked =>
            new(
                AttackResolutionType.StaminaBlocked,
                0,
                0,
                default,
                default,
                0,
                0);
    }

    public enum AttackResolutionType
    {
        StaminaBlocked,
        Miss,
        Hit
    }
}
