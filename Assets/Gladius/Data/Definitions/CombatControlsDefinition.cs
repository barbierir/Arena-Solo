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
        [SerializeField] private int minDamage;

        public string Id => id;
        public float BaseHitChance => baseHitChance;
        public float HitDeltaPerPoint => hitDeltaPerPoint;
        public float MinHitChance => minHitChance;
        public float MaxHitChance => maxHitChance;
        public int MinDamage => minDamage;
    }
}
