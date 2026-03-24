namespace Gladius.Data.Definitions
{
    public readonly struct ComputedBuildStats
    {
        public ComputedBuildStats(int maxHp, int maxSta, int atk, int def, int spd, int skl, float totalHitModPct, float totalCritModPct)
        {
            MaxHp = maxHp;
            MaxSta = maxSta;
            Atk = atk;
            Def = def;
            Spd = spd;
            Skl = skl;
            TotalHitModPct = totalHitModPct;
            TotalCritModPct = totalCritModPct;
        }

        public int MaxHp { get; }
        public int MaxSta { get; }
        public int Atk { get; }
        public int Def { get; }
        public int Spd { get; }
        public int Skl { get; }
        public float TotalHitModPct { get; }
        public float TotalCritModPct { get; }
    }
}
