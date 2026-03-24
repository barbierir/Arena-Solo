using Gladius.Data.Definitions;
using Gladius.Data.Runtime;

namespace Gladius.Combat.Systems
{
    public sealed class StatusSystem
    {
        private readonly StatusEffectDefinition[] _statusDefinitions;

        public StatusSystem(StatusEffectDefinition[] statusDefinitions)
        {
            _statusDefinitions = statusDefinitions;
        }

        public void Apply(GladiatorRuntimeState state, string statusId, int turns)
        {
            if (string.IsNullOrEmpty(statusId) || turns <= 0)
            {
                return;
            }

            var existing = state.ActiveStatuses.Find(x => x.StatusId == statusId);
            if (existing != null)
            {
                existing.RemainingTurns = turns;
                return;
            }

            state.ActiveStatuses.Add(new StatusRuntimeState { StatusId = statusId, RemainingTurns = turns });
        }

        public bool HasSkipTurnStatus(GladiatorRuntimeState state)
        {
            foreach (var status in state.ActiveStatuses)
            {
                var def = Find(status.StatusId);
                if (def != null && def.SkipTurn)
                {
                    return true;
                }
            }

            return false;
        }

        public int GetStaRegenMod(GladiatorRuntimeState state)
        {
            var total = 0;
            foreach (var status in state.ActiveStatuses)
            {
                var def = Find(status.StatusId);
                if (def != null)
                {
                    total += def.StaRegenMod;
                }
            }

            return total;
        }

        public void TickEndTurn(GladiatorRuntimeState state)
        {
            for (var i = state.ActiveStatuses.Count - 1; i >= 0; i--)
            {
                state.ActiveStatuses[i].RemainingTurns--;
                if (state.ActiveStatuses[i].RemainingTurns <= 0)
                {
                    state.ActiveStatuses.RemoveAt(i);
                }
            }
        }

        public int ApplyDotDamage(GladiatorRuntimeState state)
        {
            var totalDamage = 0;
            foreach (var status in state.ActiveStatuses)
            {
                var def = Find(status.StatusId);
                if (def != null)
                {
                    totalDamage += def.DotDamage;
                }
            }

            if (totalDamage > 0)
            {
                state.CurrentHp -= totalDamage;
                if (state.CurrentHp < 0)
                {
                    state.CurrentHp = 0;
                }
            }

            return totalDamage;
        }

        private StatusEffectDefinition Find(string id)
        {
            foreach (var status in _statusDefinitions)
            {
                if (status.Id == id)
                {
                    return status;
                }
            }

            return null;
        }
    }
}
