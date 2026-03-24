using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class CombatControlsDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private float baseHitChance;
        [SerializeField] private float hitDeltaPerPoint;
        [SerializeField] private float minHitChance;
        [SerializeField] private float maxHitChance;
        [SerializeField] private float dodgeBonusIfDefenderSpdLeadGte5;
        [SerializeField] private float baseCritChance;
        [SerializeField] private float critPerSkl;
        [SerializeField] private float critChanceCap;
        [SerializeField] private float critMultiplier;
        [SerializeField] private int minDamage;
        [SerializeField] private int baseStaminaRegen;
        [SerializeField] private int recoverBonusStamina;
        [SerializeField] private int defendBonusDef;
        [SerializeField] private int bleedDamagePerTurn;

        public string Id => id;
        public float BaseHitChance => baseHitChance;
        public float HitDeltaPerPoint => hitDeltaPerPoint;
        public float MinHitChance => minHitChance;
        public float MaxHitChance => maxHitChance;
        public float DodgeBonusIfDefenderSpdLeadGte5 => dodgeBonusIfDefenderSpdLeadGte5;
        public float BaseCritChance => baseCritChance;
        public float CritPerSkl => critPerSkl;
        public float CritChanceCap => critChanceCap;
        public float CritMultiplier => critMultiplier;
        public int MinDamage => minDamage;
        public int BaseStaminaRegen => baseStaminaRegen;
        public int RecoverBonusStamina => recoverBonusStamina;
        public int DefendBonusDef => defendBonusDef;
        public int BleedDamagePerTurn => bleedDamagePerTurn;
    }
}
