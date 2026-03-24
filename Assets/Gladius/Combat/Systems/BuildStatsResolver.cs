using System;
using System.Collections.Generic;
using Gladius.Data.Definitions;

namespace Gladius.Combat.Systems
{
    public sealed class BuildStatsResolver
    {
        private readonly Dictionary<string, ClassDefinition> _classesById;
        private readonly Dictionary<string, EquipmentDefinition> _equipmentById;

        public BuildStatsResolver(ClassDefinition[] classes, EquipmentDefinition[] equipment)
        {
            _classesById = new Dictionary<string, ClassDefinition>(StringComparer.Ordinal);
            _equipmentById = new Dictionary<string, EquipmentDefinition>(StringComparer.Ordinal);

            foreach (var classDef in classes)
            {
                _classesById[classDef.Id] = classDef;
            }

            foreach (var item in equipment)
            {
                _equipmentById[item.Id] = item;
            }
        }

        public ComputedBuildStats Resolve(BuildDefinition build)
        {
            var classDef = _classesById[build.ClassId];
            var stats = new MutableStats
            {
                Hp = classDef.BaseHp + build.BonusHp,
                Sta = classDef.BaseSta + build.BonusSta,
                Atk = classDef.BaseAtk + build.BonusAtk,
                Def = classDef.BaseDef + build.BonusDef,
                Spd = classDef.BaseSpd + build.BonusSpd,
                Skl = classDef.BaseSkl + build.BonusSkl
            };

            ApplyItem(build.WeaponItemId, ref stats);
            ApplyItem(build.OffhandItemId, ref stats);
            ApplyItem(build.ArmorItemId, ref stats);
            ApplyItem(build.AccessoryItemId, ref stats);

            return new ComputedBuildStats(stats.Hp, stats.Sta, stats.Atk, stats.Def, stats.Spd, stats.Skl, stats.HitMod, stats.CritMod);
        }

        private void ApplyItem(string itemId, ref MutableStats stats)
        {
            if (string.IsNullOrEmpty(itemId) || !_equipmentById.TryGetValue(itemId, out var item))
            {
                return;
            }

            stats.Hp += item.HpMod;
            stats.Sta += item.StaMod;
            stats.Atk += item.AtkMod;
            stats.Def += item.DefMod;
            stats.Spd += item.SpdMod;
            stats.Skl += item.SklMod;
            stats.HitMod += item.HitModPct;
            stats.CritMod += item.CritModPct;
        }

        private struct MutableStats
        {
            public int Hp;
            public int Sta;
            public int Atk;
            public int Def;
            public int Spd;
            public int Skl;
            public float HitMod;
            public float CritMod;
        }
    }
}
