using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class SkillDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string ownerClassId;
        [SerializeField] private int staminaCost;
        [SerializeField] private string targetType;
        [SerializeField] private string effectId;

        public string Id => id;
        public string OwnerClassId => ownerClassId;
        public int StaminaCost => staminaCost;
        public string TargetType => targetType;
        public string EffectId => effectId;
    }
}
