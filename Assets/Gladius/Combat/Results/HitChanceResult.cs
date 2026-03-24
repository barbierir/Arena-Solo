namespace Gladius.Combat.Results
{
    public readonly struct HitChanceResult
    {
        public HitChanceResult(double probability, double roll, bool didHit)
        {
            Probability = probability;
            Roll = roll;
            DidHit = didHit;
        }

        public double Probability { get; }
        public double Roll { get; }
        public bool DidHit { get; }
    }
}
