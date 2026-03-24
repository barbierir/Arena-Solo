using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class StaminaSystem
    {
        private readonly CombatControlsDefinition _controls;

        public StaminaSystem(CombatControlsDefinition controls)
        {
            _controls = controls;
        }

        public bool HasEnough(GladiatorRuntimeState state, int cost) => state.CurrentStamina >= cost;

        public void Spend(GladiatorRuntimeState state, int cost)
        {
            state.CurrentStamina -= cost;
            if (state.CurrentStamina < 0)
            {
                state.CurrentStamina = 0;
            }
        }

        public void StartTurnRegen(GladiatorRuntimeState state, int statusStaRegenMod)
        {
            state.CurrentStamina += _controls.BaseStaminaRegen + statusStaRegenMod;
            if (state.CurrentStamina > state.MaxStamina)
            {
                state.CurrentStamina = state.MaxStamina;
            }

            if (state.CurrentStamina < 0)
            {
                state.CurrentStamina = 0;
            }
        }

        public void ApplyRecover(GladiatorRuntimeState state)
        {
            state.CurrentStamina += _controls.RecoverBonusStamina;
            if (state.CurrentStamina > state.MaxStamina)
            {
                state.CurrentStamina = state.MaxStamina;
            }
        }
    }
}
