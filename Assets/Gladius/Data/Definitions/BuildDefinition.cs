using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class BuildDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string classId;
        [SerializeField] private string weaponItemId;
        [SerializeField] private string offhandItemId;
        [SerializeField] private string armorItemId;
        [SerializeField] private string accessoryItemId;
        [SerializeField] private int bonusHp;
        [SerializeField] private int bonusSta;
        [SerializeField] private int bonusAtk;
        [SerializeField] private int bonusDef;
        [SerializeField] private int bonusSpd;
        [SerializeField] private int bonusSkl;

        public string Id => id;
        public string DisplayName => displayName;
        public string ClassId => classId;
        public string WeaponItemId => weaponItemId;
        public string OffhandItemId => offhandItemId;
        public string ArmorItemId => armorItemId;
        public string AccessoryItemId => accessoryItemId;
        public int BonusHp => bonusHp;
        public int BonusSta => bonusSta;
        public int BonusAtk => bonusAtk;
        public int BonusDef => bonusDef;
        public int BonusSpd => bonusSpd;
        public int BonusSkl => bonusSkl;
    }
}
