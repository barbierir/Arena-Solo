using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class StatusSystem
    {
        public void Tick(GladiatorRuntimeState state)
        {
            for (var i = state.ActiveEffects.Count - 1; i >= 0; i--)
            {
                state.ActiveEffects[i].RemainingTurns -= 1;

                if (state.ActiveEffects[i].RemainingTurns <= 0)
                {
                    state.ActiveEffects.RemoveAt(i);
                }
            }
        }
    }
}
