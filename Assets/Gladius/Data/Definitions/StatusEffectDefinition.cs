using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class StatusEffectDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string stackRule;
        [SerializeField] private int atkMod;
        [SerializeField] private int defMod;
        [SerializeField] private int spdMod;
        [SerializeField] private int staRegenMod;
        [SerializeField] private int dotDamage;
        [SerializeField] private bool skipTurn;
        [SerializeField] private string durationSource;
        [SerializeField] private string notes;

        public string Id => id;
        public string DisplayName => displayName;
        public string StackRule => stackRule;
        public int AtkMod => atkMod;
        public int DefMod => defMod;
        public int SpdMod => spdMod;
        public int StaRegenMod => staRegenMod;
        public int DotDamage => dotDamage;
        public bool SkipTurn => skipTurn;
        public string DurationSource => durationSource;
        public string Notes => notes;
    }
}
