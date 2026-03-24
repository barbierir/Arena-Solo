using System.Collections.Generic;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

namespace Gladius.Combat.Core
{
    public sealed class SecutorAiController
    {
        public string SelectSkill(
            GladiatorRuntimeState self,
            GladiatorRuntimeState enemy,
            IReadOnlyList<SkillDefinition> legalSkills,
            AIProfileDefinition profile)
        {
            if (legalSkills.Count == 0)
            {
                return "RECOVER";
            }

            if (enemy.CurrentHp <= profile.PreferKillThresholdHp && Contains(legalSkills, "BASIC_ATTACK"))
            {
                return "BASIC_ATTACK";
            }

            if (profile.AllowStatusSetup && !HasStatus(enemy, "STUNNED") && Contains(legalSkills, "SHIELD_BASH"))
            {
                return "SHIELD_BASH";
            }

            if (self.CurrentStamina <= profile.RecoverAtOrBelowSta && Contains(legalSkills, "RECOVER"))
            {
                return "RECOVER";
            }

            if (Contains(legalSkills, "BASIC_ATTACK"))
            {
                return "BASIC_ATTACK";
            }

            return legalSkills[0].Id;
        }

        private static bool Contains(IReadOnlyList<SkillDefinition> skills, string id)
        {
            foreach (var skill in skills)
            {
                if (skill.Id == id)
                {
                    return true;
                }
            }

            return false;
        }

        private static bool HasStatus(GladiatorRuntimeState state, string statusId)
        {
            foreach (var status in state.ActiveStatuses)
            {
                if (status.StatusId == statusId)
                {
                    return true;
                }
            }

            return false;
        }
    }
}
