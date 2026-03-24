using System;
using UnityEngine;

namespace Gladius.Data.Definitions
{
    [Serializable]
    public sealed class AIProfileDefinition
    {
        [SerializeField] private string id;
        [SerializeField] private string displayName;
        [SerializeField] private int recoverAtOrBelowSta;
        [SerializeField] private int preferKillThresholdHp;
        [SerializeField] private bool allowStatusSetup;

        public string Id => id;
        public string DisplayName => displayName;
        public int RecoverAtOrBelowSta => recoverAtOrBelowSta;
        public int PreferKillThresholdHp => preferKillThresholdHp;
        public bool AllowStatusSetup => allowStatusSetup;
    }
}
