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

        private TurnSystem _turnSystem;
        private ActionResolver _actionResolver;
        private GladiatorRuntimeState _left;
        private GladiatorRuntimeState _right;

        private void Awake()
        {
            var content = new BootstrapContentLoader().Load();
            var controls = content.controls ?? new CombatControlsDefinition();

            var rngService = new SeededRngService(seed);
            _actionResolver = new ActionResolver(
                new Systems.DamageSystem(controls),
                new Systems.HitChanceSystem(controls),
                new Systems.StatusSystem(),
                new Systems.StaminaSystem(),
                rngService);

            _turnSystem = new TurnSystem();
            _left = GladiatorRuntimeState.FromDefinition(FindGladiator(content, "RET_STARTER"));
            _right = GladiatorRuntimeState.FromDefinition(FindGladiator(content, "SEC_STARTER"));
            _turnSystem.Initialize(_left, _right);
        }

        private void Start()
        {
            Debug.Log("CombatManager initialized. Foundation layer ready.");
        }

        private static GladiatorDefinition FindGladiator(BootstrapContentDefinition content, string id)
        {
            if (content.gladiators == null)
            {
                return null;
            }

            foreach (var gladiator in content.gladiators)
            {
                if (gladiator != null && gladiator.Id == id)
                {
                    return gladiator;
                }
            }

            return null;
        }
    }
}
