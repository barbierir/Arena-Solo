using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class EquipmentDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string slot;
        [SerializeField] private string[] allowedClassIds;
        [SerializeField] private int atkMod;
        [SerializeField] private int defMod;
        [SerializeField] private int spdMod;
        [SerializeField] private int sklMod;
        [SerializeField] private int hpMod;
        [SerializeField] private int staMod;
        [SerializeField] private float hitModPct;
        [SerializeField] private float critModPct;
        [SerializeField] private string notes;

        public string Id => id;
        public string DisplayName => displayName;
        public string Slot => slot;
        public string[] AllowedClassIds => allowedClassIds;
        public int AtkMod => atkMod;
        public int DefMod => defMod;
        public int SpdMod => spdMod;
        public int SklMod => sklMod;
        public int HpMod => hpMod;
        public int StaMod => staMod;
        public float HitModPct => hitModPct;
        public float CritModPct => critModPct;
        public string Notes => notes;
    }
}
