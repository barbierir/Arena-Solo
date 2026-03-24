using System;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class BootstrapContentDefinition
    {
        public CombatControlsDefinition controls;
        public GladiatorDefinition[] gladiators;
        public EquipmentDefinition[] equipment;
        public SkillDefinition[] skills;
        public StatusEffectDefinition[] statuses;
    }
}
