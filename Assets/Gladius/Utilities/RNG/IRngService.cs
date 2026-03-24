namespace Gladius.Utilities.RNG
{
    public interface IRngService
    {
        int NextInt(int minInclusive, int maxExclusive);
        double NextDouble();
    }
}
