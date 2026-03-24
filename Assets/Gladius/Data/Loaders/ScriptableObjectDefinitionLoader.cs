using System.Collections.Generic;

namespace Gladius.Data.Loaders
{
    public sealed class ScriptableObjectDefinitionLoader<T> : IDefinitionLoader<T>
    {
        public IReadOnlyDictionary<string, T> LoadAll()
        {
            // Stub: wired in future implementation step.
            return new Dictionary<string, T>();
        }
    }
}
