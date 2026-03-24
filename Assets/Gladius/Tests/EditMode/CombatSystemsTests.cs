using Gladius.Combat.Core;
using Gladius.Combat.Systems;
using Gladius.Data.Definitions;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;
using NUnit.Framework;

namespace Gladius.Tests.EditMode
{
    public sealed class CombatSystemsTests
    {
        [Test]
        public void HitChance_BasicAttack_RetVsSec_IsExpectedWorkbookValue()
        {
            var controls = TestData.Controls();
            var hitSystem = new HitChanceSystem(controls);
            var attacker = TestData.RetState();
            var defender = TestData.SecState();
            var skill = TestData.Skill("BASIC_ATTACK");

            var result = hitSystem.Resolve(attacker, defender, skill, 0f, new SeededRngService(1));

            Assert.AreEqual(0.8d, result.Probability, 0.0001d);
        }

        [Test]
        public void Damage_BasicAttack_RetVsSec_RespectsMinDamage()
        {
            var system = new DamageSystem(TestData.Controls());

            var result = system.Calculate(TestData.RetState(), TestData.SecState(), TestData.Skill("BASIC_ATTACK"), false);

            Assert.AreEqual(1, result.FinalDamage);
        }

        [Test]
        public void Stamina_StartTurnAndRecover_UsesControlValues()
        {
            var state = TestData.RetState();
            state.CurrentStamina = 5;
            var stamina = new StaminaSystem(TestData.Controls());

            stamina.StartTurnRegen(state, 0);
            stamina.ApplyRecover(state);

            Assert.AreEqual(9, state.CurrentStamina);
        }

        [Test]
        public void TurnSystem_HigherSpeedActsFirst()
        {
            var turn = new TurnSystem();
            var ret = TestData.RetState();
            var sec = TestData.SecState();

            turn.Initialize(ret, sec);

            Assert.AreEqual(ret, turn.CurrentActor);
            Assert.AreEqual(sec, turn.CurrentTarget);
        }

        private static class TestData
        {
            public static CombatControlsDefinition Controls()
            {
                return UnityEngine.JsonUtility.FromJson<CombatControlsDefinition>("{\"id\":\"COMBAT_CONTROLS\",\"baseHitChance\":0.7,\"hitDeltaPerPoint\":0.02,\"minHitChance\":0.1,\"maxHitChance\":0.95,\"dodgeBonusIfDefenderSpdLeadGte5\":0.15,\"baseCritChance\":0.05,\"critPerSkl\":0.01,\"critChanceCap\":0.5,\"critMultiplier\":2.0,\"minDamage\":1,\"baseStaminaRegen\":2,\"recoverBonusStamina\":2,\"defendBonusDef\":2,\"bleedDamagePerTurn\":2}");
            }

            public static GladiatorRuntimeState RetState()
            {
                return new GladiatorRuntimeState { ClassId = "RETIARIUS", Atk = 8, Def = 4, Spd = 8, Skl = 9, MaxStamina = 10, CurrentStamina = 10, MaxHp = 22, CurrentHp = 22 };
            }

            public static GladiatorRuntimeState SecState()
            {
                return new GladiatorRuntimeState { ClassId = "SECUTOR", Atk = 9, Def = 10, Spd = 3, Skl = 5, MaxStamina = 9, CurrentStamina = 9, MaxHp = 26, CurrentHp = 26 };
            }

            public static SkillDefinition Skill(string id)
            {
                if (id == "BASIC_ATTACK")
                {
                    return UnityEngine.JsonUtility.FromJson<SkillDefinition>("{\"id\":\"BASIC_ATTACK\",\"displayName\":\"Basic Attack\",\"usableBy\":\"ANY\",\"staCost\":2,\"accuracyModPct\":0,\"flatDamage\":0,\"critBonusPct\":0,\"selfDefMod\":0,\"applyStatusId\":\"\",\"statusTurns\":0,\"cooldownTurns\":0,\"targetType\":\"Enemy\"}");
                }

                return null;
            }
        }
    }
}
