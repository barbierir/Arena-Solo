using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class StatusEffectDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string stackRule;
        [SerializeField] private int defaultDuration;

        public string Id => id;
        public string StackRule => stackRule;
        public int DefaultDuration => defaultDuration;
    }
}
