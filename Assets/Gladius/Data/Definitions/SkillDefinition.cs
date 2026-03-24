using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class SkillDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string usableBy;
        [SerializeField] private int staCost;
        [SerializeField] private float accuracyModPct;
        [SerializeField] private int flatDamage;
        [SerializeField] private float critBonusPct;
        [SerializeField] private int selfDefMod;
        [SerializeField] private string applyStatusId;
        [SerializeField] private int statusTurns;
        [SerializeField] private int cooldownTurns;
        [SerializeField] private string targetType;

        public string Id => id;
        public string DisplayName => displayName;
        public string UsableBy => usableBy;
        public int StaCost => staCost;
        public float AccuracyModPct => accuracyModPct;
        public int FlatDamage => flatDamage;
        public float CritBonusPct => critBonusPct;
        public int SelfDefMod => selfDefMod;
        public string ApplyStatusId => applyStatusId;
        public int StatusTurns => statusTurns;
        public int CooldownTurns => cooldownTurns;
        public string TargetType => targetType;
    }
}
