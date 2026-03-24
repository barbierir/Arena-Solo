using System.Collections.Generic;
using Gladius.Data.Definitions;

namespace Gladius.Data.Runtime
{
    public sealed class GladiatorRuntimeState
    {
        public string GladiatorId { get; set; }
        public int MaxHp { get; set; }
        public int CurrentHp { get; set; }
        public int MaxStamina { get; set; }
        public int CurrentStamina { get; set; }
        public int Attack { get; set; }
        public int Defense { get; set; }
        public int Accuracy { get; set; }
        public int Evasion { get; set; }
        public List<StatusRuntimeState> ActiveEffects { get; } = new();

        public static GladiatorRuntimeState FromDefinition(GladiatorDefinition definition)
        {
            if (definition == null)
            {
                return new GladiatorRuntimeState();
            }

            return new GladiatorRuntimeState
            {
                GladiatorId = definition.Id,
                MaxHp = definition.MaxHp,
                CurrentHp = definition.MaxHp,
                MaxStamina = definition.MaxStamina,
                CurrentStamina = definition.MaxStamina,
                Attack = definition.Attack,
                Defense = definition.Defense,
                Accuracy = definition.Accuracy,
                Evasion = definition.Evasion
            };
        }
    }
}
