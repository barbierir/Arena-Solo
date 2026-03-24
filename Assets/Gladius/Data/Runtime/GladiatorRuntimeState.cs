using System.Collections.Generic;

namespace Gladius.Data.Runtime
{
    public sealed class GladiatorRuntimeState
    {
        public string CombatantId { get; set; }
        public string BuildId { get; set; }
        public string ClassId { get; set; }
        public string DisplayName { get; set; }
        public int MaxHp { get; set; }
        public int CurrentHp { get; set; }
        public int MaxStamina { get; set; }
        public int CurrentStamina { get; set; }
        public int Atk { get; set; }
        public int Def { get; set; }
        public int Spd { get; set; }
        public int Skl { get; set; }
        public float TotalHitModPct { get; set; }
        public float TotalCritModPct { get; set; }
        public int TempDefBonus { get; set; }

        public List<StatusRuntimeState> ActiveStatuses { get; } = new();
        public Dictionary<string, int> Cooldowns { get; } = new();

        public bool IsAlive => CurrentHp > 0;
    }
}
