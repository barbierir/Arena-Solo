using Gladius.Data.Definitions;
using Gladius.Data.Definitions.Collections;
using UnityEngine;

namespace Gladius.Data.Loaders
{
    public sealed class BootstrapContentLoader
    {
        private const string DefinitionsRoot = "Data/Definitions/";
        private const string GladiatorsPath = DefinitionsRoot + "gladiators";
        private const string EquipmentPath = DefinitionsRoot + "equipment";
        private const string SkillsPath = DefinitionsRoot + "skills";
        private const string StatusEffectsPath = DefinitionsRoot + "status_effects";
        private const string CombatRulesPath = DefinitionsRoot + "combat_rules";

        public BootstrapContentDefinition Load()
        {
            var gladiators = LoadCollection<GladiatorDefinitionsCollection>(GladiatorsPath) ?? new GladiatorDefinitionsCollection();
            var equipment = LoadCollection<EquipmentDefinitionsCollection>(EquipmentPath) ?? new EquipmentDefinitionsCollection();
            var skills = LoadCollection<SkillDefinitionsCollection>(SkillsPath) ?? new SkillDefinitionsCollection();
            var statusEffects = LoadCollection<StatusEffectDefinitionsCollection>(StatusEffectsPath) ?? new StatusEffectDefinitionsCollection();
            var combatRules = LoadCollection<CombatRulesDefinitionCollection>(CombatRulesPath) ?? new CombatRulesDefinitionCollection();

            return new BootstrapContentDefinition
            {
                controls = combatRules.controls ?? new CombatControlsDefinition(),
                gladiators = gladiators.gladiators ?? System.Array.Empty<GladiatorDefinition>(),
                equipment = equipment.equipment ?? System.Array.Empty<EquipmentDefinition>(),
                skills = skills.skills ?? System.Array.Empty<SkillDefinition>(),
                statusEffects = statusEffects.statusEffects ?? System.Array.Empty<StatusEffectDefinition>()
            };
        }

        private static T LoadCollection<T>(string resourcePath) where T : class
        {
            var asset = Resources.Load<TextAsset>(resourcePath);
            if (asset == null)
            {
                Debug.LogError($"Missing definition data at Resources/{resourcePath}.json");
                return null;
            }

            return JsonUtility.FromJson<T>(asset.text);
        }
    }
}
