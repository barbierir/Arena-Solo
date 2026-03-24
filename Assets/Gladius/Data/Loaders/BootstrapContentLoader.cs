using Gladius.Data.Definitions;
using UnityEngine;

namespace Gladius.Data.Loaders
{
    public sealed class BootstrapContentLoader
    {
        private const string ResourcePath = "Data/Definitions/bootstrap_content";

        public BootstrapContentDefinition Load()
        {
            var asset = Resources.Load<TextAsset>(ResourcePath);
            if (asset == null)
            {
                Debug.LogError($"Missing bootstrap data at Resources/{ResourcePath}.json");
                return new BootstrapContentDefinition();
            }

            var content = JsonUtility.FromJson<BootstrapContentDefinition>(asset.text);
            return content ?? new BootstrapContentDefinition();
        }
    }
}
