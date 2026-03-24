using Gladius.Data.Definitions;
using Gladius.Data.Definitions.Collections;
using UnityEngine;

namespace Gladius.Data.Loaders
{
    public sealed class BootstrapContentLoader
    {
        private const string DefinitionsRoot = "Data/Definitions/";
        private const string ClassesPath = DefinitionsRoot + "classes";
        private const string BuildsPath = DefinitionsRoot + "builds";
        private const string EquipmentPath = DefinitionsRoot + "equipment";
        private const string SkillsPath = DefinitionsRoot + "skills";
        private const string StatusEffectsPath = DefinitionsRoot + "status_effects";
        private const string CombatRulesPath = DefinitionsRoot + "combat_rules";
        private const string AiProfilesPath = DefinitionsRoot + "ai_profiles";
        private const string EncountersPath = DefinitionsRoot + "encounters";

        public BootstrapContentDefinition Load()
        {
            var classes = LoadCollection<ClassDefinitionsCollection>(ClassesPath) ?? new ClassDefinitionsCollection();
            var builds = LoadCollection<BuildDefinitionsCollection>(BuildsPath) ?? new BuildDefinitionsCollection();
            var equipment = LoadCollection<EquipmentDefinitionsCollection>(EquipmentPath) ?? new EquipmentDefinitionsCollection();
            var skills = LoadCollection<SkillDefinitionsCollection>(SkillsPath) ?? new SkillDefinitionsCollection();
            var statusEffects = LoadCollection<StatusEffectDefinitionsCollection>(StatusEffectsPath) ?? new StatusEffectDefinitionsCollection();
            var combatRules = LoadCollection<CombatRulesDefinitionCollection>(CombatRulesPath) ?? new CombatRulesDefinitionCollection();
            var aiProfiles = LoadCollection<AIProfileDefinitionsCollection>(AiProfilesPath) ?? new AIProfileDefinitionsCollection();
            var encounters = LoadCollection<EncounterDefinitionsCollection>(EncountersPath) ?? new EncounterDefinitionsCollection();

            return new BootstrapContentDefinition
            {
                controls = combatRules.controls ?? new CombatControlsDefinition(),
                classes = classes.classes ?? System.Array.Empty<ClassDefinition>(),
                builds = builds.builds ?? System.Array.Empty<BuildDefinition>(),
                equipment = equipment.equipment ?? System.Array.Empty<EquipmentDefinition>(),
                skills = skills.skills ?? System.Array.Empty<SkillDefinition>(),
                statusEffects = statusEffects.statusEffects ?? System.Array.Empty<StatusEffectDefinition>(),
                aiProfiles = aiProfiles.aiProfiles ?? System.Array.Empty<AIProfileDefinition>(),
                encounters = encounters.encounters ?? System.Array.Empty<EncounterDefinition>()
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
