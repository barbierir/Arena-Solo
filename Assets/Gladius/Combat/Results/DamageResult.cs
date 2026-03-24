namespace Gladius.Combat.Results
{
    public readonly struct DamageResult
    {
        public DamageResult(int rawDamage, int minDamageCap, int finalDamage)
        {
            RawDamage = rawDamage;
            MinDamageCap = minDamageCap;
            FinalDamage = finalDamage;
        }

        public int RawDamage { get; }
        public int MinDamageCap { get; }
        public int FinalDamage { get; }
    }
}
