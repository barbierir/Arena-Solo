using Gladius.Data.Runtime;

namespace Gladius.Combat.Core
{
    public sealed class TurnSystem
    {
        public GladiatorRuntimeState CurrentActor { get; private set; }
        public GladiatorRuntimeState CurrentTarget { get; private set; }

        public void Initialize(GladiatorRuntimeState first, GladiatorRuntimeState second)
        {
            CurrentActor = first;
            CurrentTarget = second;
        }

        public void AdvanceTurn()
        {
            (CurrentActor, CurrentTarget) = (CurrentTarget, CurrentActor);
        }
    }
}
