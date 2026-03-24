using System;

namespace Gladius.Utilities.RNG
{
    public sealed class SeededRngService : IRngService
    {
        private readonly Random _random;

        public SeededRngService(int seed)
        {
            _random = new Random(seed);
        }

        public int NextInt(int minInclusive, int maxExclusive)
        {
            return _random.Next(minInclusive, maxExclusive);
        }

        public double NextDouble()
        {
            return _random.NextDouble();
        }
    }
}
