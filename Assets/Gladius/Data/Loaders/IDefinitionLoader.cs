using System.Collections.Generic;

namespace Gladius.Data.Loaders
{
    public interface IDefinitionLoader<T>
    {
        IReadOnlyDictionary<string, T> LoadAll();
    }
}
