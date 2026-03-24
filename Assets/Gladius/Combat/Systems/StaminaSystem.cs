using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class StaminaSystem
    {
        public bool HasEnough(GladiatorRuntimeState state, int cost)
        {
            return state.CurrentStamina >= cost;
        }

        public void Spend(GladiatorRuntimeState state, int cost)
        {
            state.CurrentStamina -= cost;
            if (state.CurrentStamina < 0)
            {
                state.CurrentStamina = 0;
            }
        }

        public void Regenerate(GladiatorRuntimeState state, int amount)
        {
            state.CurrentStamina += amount;
            if (state.CurrentStamina > state.MaxStamina)
            {
                state.CurrentStamina = state.MaxStamina;
            }
        }
    }
}
