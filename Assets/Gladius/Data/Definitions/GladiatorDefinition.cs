using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class GladiatorDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string classId;
        [SerializeField] private string buildId;
        [SerializeField] private int maxHp;
        [SerializeField] private int maxStamina;
        [SerializeField] private int attack;
        [SerializeField] private int defense;
        [SerializeField] private int accuracy;
        [SerializeField] private int evasion;

        public string Id => id;
        public string ClassId => classId;
        public string BuildId => buildId;
        public int MaxHp => maxHp;
        public int MaxStamina => maxStamina;
        public int Attack => attack;
        public int Defense => defense;
        public int Accuracy => accuracy;
        public int Evasion => evasion;
    }
}
