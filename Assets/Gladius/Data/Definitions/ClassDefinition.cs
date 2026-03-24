using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class ClassDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string role;
        [SerializeField] private int baseHp;
        [SerializeField] private int baseSta;
        [SerializeField] private int baseAtk;
        [SerializeField] private int baseDef;
        [SerializeField] private int baseSpd;
        [SerializeField] private int baseSkl;
        [SerializeField] private string passiveNotes;
        [SerializeField] private string[] allowedSkillIds;

        public string Id => id;
        public string DisplayName => displayName;
        public string Role => role;
        public int BaseHp => baseHp;
        public int BaseSta => baseSta;
        public int BaseAtk => baseAtk;
        public int BaseDef => baseDef;
        public int BaseSpd => baseSpd;
        public int BaseSkl => baseSkl;
        public string PassiveNotes => passiveNotes;
        public string[] AllowedSkillIds => allowedSkillIds;
    }
}
