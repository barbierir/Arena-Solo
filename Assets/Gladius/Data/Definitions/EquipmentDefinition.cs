using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class EquipmentDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string slot;
        [SerializeField] private int attackBonus;
        [SerializeField] private int defenseBonus;

        public string Id => id;
        public string Slot => slot;
        public int AttackBonus => attackBonus;
        public int DefenseBonus => defenseBonus;
    }
}
