using Gladius.Data.Runtime;

namespace Gladius.Combat.Core
{
    public sealed class TurnSystem
    {
        public GladiatorRuntimeState CurrentActor { get; private set; }
        public GladiatorRuntimeState CurrentTarget { get; private set; }

        public void Initialize(GladiatorRuntimeState player, GladiatorRuntimeState enemy)
        {
            if (player.Spd >= enemy.Spd)
            {
                CurrentActor = player;
                CurrentTarget = enemy;
            }
            else
            {
                CurrentActor = enemy;
                CurrentTarget = player;
            }
        }

        public void AdvanceTurn()
        {
            (CurrentActor, CurrentTarget) = (CurrentTarget, CurrentActor);
        }
    }
}
