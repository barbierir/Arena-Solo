using System;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class BootstrapContentDefinition
    {
        public CombatControlsDefinition controls;
        public ClassDefinition[] classes;
        public BuildDefinition[] builds;
        public EquipmentDefinition[] equipment;
        public SkillDefinition[] skills;
        public StatusEffectDefinition[] statusEffects;
        public AIProfileDefinition[] aiProfiles;
        public EncounterDefinition[] encounters;
    }
}
