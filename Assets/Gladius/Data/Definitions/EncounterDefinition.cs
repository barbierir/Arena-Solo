using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class EncounterDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private string mode;
        [SerializeField] private string playerBuildId;
        [SerializeField] private string enemyBuildId;
        [SerializeField] private string enemyAiProfileId;
        [SerializeField] private int rewardGold;
        [SerializeField] private int rewardXp;

        public string Id => id;
        public string DisplayName => displayName;
        public string Mode => mode;
        public string PlayerBuildId => playerBuildId;
        public string EnemyBuildId => enemyBuildId;
        public string EnemyAiProfileId => enemyAiProfileId;
        public int RewardGold => rewardGold;
        public int RewardXp => rewardXp;
    }
}
