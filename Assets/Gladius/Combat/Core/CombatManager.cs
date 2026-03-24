using System.Collections.Generic;
using Gladius.Combat.Systems;
using Gladius.Data.Definitions;
using Gladius.Data.Loaders;
using Gladius.Data.Runtime;
using Gladius.Utilities.RNG;
using UnityEngine;

namespace Gladius.Combat.Core
{
    public sealed class CombatManager : MonoBehaviour
    {
        [SerializeField] private int seed = 12345;

        private readonly List<string> _combatLog = new();

        private TurnSystem _turnSystem;
        private ActionResolver _actionResolver;
        private SecutorAiController _ai;
        private GladiatorRuntimeState _player;
        private GladiatorRuntimeState _enemy;
        private AIProfileDefinition _enemyAiProfile;
        private bool _combatEnded;

        private void Awake()
        {
            var content = new BootstrapContentLoader().Load();
            var encounter = FindEncounter(content, "STARTER_DUEL_RET_VS_SEC");
            var playerBuild = FindBuild(content, encounter.PlayerBuildId);
            var enemyBuild = FindBuild(content, encounter.EnemyBuildId);

            var resolver = new BuildStatsResolver(content.classes, content.equipment);
            _player = CreateRuntimeState("PLAYER", playerBuild, resolver.Resolve(playerBuild));
            _enemy = CreateRuntimeState("ENEMY", enemyBuild, resolver.Resolve(enemyBuild));

            _enemyAiProfile = FindAiProfile(content, encounter.EnemyAiProfileId);
            _turnSystem = new TurnSystem();
            _turnSystem.Initialize(_player, _enemy);
            _ai = new SecutorAiController();

            var rngService = new SeededRngService(seed);
            _actionResolver = new ActionResolver(
                content.skills,
                content.controls,
                new DamageSystem(content.controls),
                new HitChanceSystem(content.controls),
                new StatusSystem(content.statusEffects),
                new StaminaSystem(content.controls),
                rngService);

            StartTurn();
            _combatLog.Add($"Encounter started: {_player.DisplayName} vs {_enemy.DisplayName}. Seed={seed}");
        }

        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(20, 20, Screen.width - 40, Screen.height - 40));
            GUILayout.Label("GLADIUS Vertical Slice - Starter Duel");
            DrawCombatant(_player, "Player");
            DrawCombatant(_enemy, "Enemy");

            if (!_combatEnded)
            {
                GUILayout.Space(8);
                GUILayout.Label($"Turn: {_turnSystem.CurrentActor.DisplayName}");
                if (_turnSystem.CurrentActor == _player)
                {
                    DrawPlayerActions();
                }
                else
                {
                    GUILayout.Label("Enemy thinking...");
                }
            }
            else
            {
                GUILayout.Label(_player.IsAlive ? "Victory!" : "Defeat!");
            }

            GUILayout.Space(8);
            GUILayout.Label("Combat Log");
            foreach (var line in _combatLog)
            {
                GUILayout.Label(line);
            }

            GUILayout.EndArea();
        }

        private void DrawPlayerActions()
        {
            var legal = _actionResolver.GetLegalSkills(_player);
            GUILayout.BeginHorizontal();
            foreach (var skill in legal)
            {
                if (GUILayout.Button(skill.DisplayName, GUILayout.Height(35)))
                {
                    ExecuteTurn(skill.Id);
                    break;
                }
            }

            GUILayout.EndHorizontal();
        }

        private void ExecuteTurn(string skillId)
        {
            var actor = _turnSystem.CurrentActor;
            var target = _turnSystem.CurrentTarget;

            if (_actionResolver.ShouldSkipTurn(actor))
            {
                _combatLog.Add($"{actor.DisplayName} is stunned and loses the turn.");
            }
            else
            {
                var result = _actionResolver.Resolve(actor, target, skillId);
                _combatLog.Add(BuildLogLine(actor, result));
            }

            var dotDamage = _actionResolver.EndTurn(actor);
            if (dotDamage > 0)
            {
                _combatLog.Add($"{actor.DisplayName} takes {dotDamage} DOT damage.");
            }

            if (CheckCombatEnd())
            {
                return;
            }

            _turnSystem.AdvanceTurn();
            StartTurn();

            if (_turnSystem.CurrentActor == _enemy)
            {
                var aiChoice = _ai.SelectSkill(_enemy, _player, _actionResolver.GetLegalSkills(_enemy), _enemyAiProfile);
                ExecuteTurn(aiChoice);
            }
        }

        private void StartTurn()
        {
            _actionResolver.StartTurn(_turnSystem.CurrentActor);
        }

        private bool CheckCombatEnd()
        {
            if (_player.IsAlive && _enemy.IsAlive)
            {
                return false;
            }

            _combatEnded = true;
            _combatLog.Add(_player.IsAlive ? "Player wins." : "Enemy wins.");
            return true;
        }

        private static string BuildLogLine(GladiatorRuntimeState actor, Results.AttackResolutionResult result)
        {
            if (result.Type == Results.AttackResolutionType.StaminaBlocked)
            {
                return $"{actor.DisplayName} tried {result.SkillId} but lacks stamina.";
            }

            if (result.Type == Results.AttackResolutionType.Miss)
            {
                return $"{actor.DisplayName} used {result.SkillId} and missed (hit {result.HitChance.Probability:0.00}).";
            }

            if (result.Damage.FinalDamage > 0)
            {
                var crit = result.IsCritical ? " CRIT!" : string.Empty;
                var status = string.IsNullOrEmpty(result.AppliedStatusId) ? string.Empty : $" Applied {result.AppliedStatusId}.";
                return $"{actor.DisplayName} used {result.SkillId} for {result.Damage.FinalDamage} damage.{crit}{status}";
            }

            return $"{actor.DisplayName} used {result.SkillId}.";
        }

        private static void DrawCombatant(GladiatorRuntimeState state, string side)
        {
            GUILayout.Label($"{side}: {state.DisplayName} | HP {state.CurrentHp}/{state.MaxHp} | STA {state.CurrentStamina}/{state.MaxStamina} | TempDEF {state.TempDefBonus}");
            if (state.ActiveStatuses.Count == 0)
            {
                GUILayout.Label("Statuses: none");
                return;
            }

            var statusText = "Statuses: ";
            for (var i = 0; i < state.ActiveStatuses.Count; i++)
            {
                if (i > 0)
                {
                    statusText += ", ";
                }

                statusText += $"{state.ActiveStatuses[i].StatusId}({state.ActiveStatuses[i].RemainingTurns})";
            }

            GUILayout.Label(statusText);
        }

        private static GladiatorRuntimeState CreateRuntimeState(string combatantId, BuildDefinition build, ComputedBuildStats stats)
        {
            return new GladiatorRuntimeState
            {
                CombatantId = combatantId,
                BuildId = build.Id,
                ClassId = build.ClassId,
                DisplayName = build.DisplayName,
                MaxHp = stats.MaxHp,
                CurrentHp = stats.MaxHp,
                MaxStamina = stats.MaxSta,
                CurrentStamina = stats.MaxSta,
                Atk = stats.Atk,
                Def = stats.Def,
                Spd = stats.Spd,
                Skl = stats.Skl,
                TotalHitModPct = stats.TotalHitModPct,
                TotalCritModPct = stats.TotalCritModPct
            };
        }

        private static BuildDefinition FindBuild(BootstrapContentDefinition content, string id)
        {
            foreach (var build in content.builds)
            {
                if (build.Id == id)
                {
                    return build;
                }
            }

            return null;
        }

        private static EncounterDefinition FindEncounter(BootstrapContentDefinition content, string id)
        {
            foreach (var encounter in content.encounters)
            {
                if (encounter.Id == id)
                {
                    return encounter;
                }
            }

            return null;
        }

        private static AIProfileDefinition FindAiProfile(BootstrapContentDefinition content, string id)
        {
            foreach (var profile in content.aiProfiles)
            {
                if (profile.Id == id)
                {
                    return profile;
                }
            }

            return null;
        }
    }
}
