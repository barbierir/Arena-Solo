from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.sim_optimizer.optimize import _apply_params


class OptimizerParamApplicationTests(unittest.TestCase):
    def _read_json(self, root: Path, name: str) -> dict:
        return json.loads((root / name).read_text(encoding="utf-8"))

    def test_apply_params_supports_classes_skills_combat_rules_and_matchup(self) -> None:
        defs_dir = Path("data/definitions")
        with tempfile.TemporaryDirectory() as td:
            candidate_dir = _apply_params(
                defs_dir=defs_dir,
                params={
                    "RETIARIUS.base_atk": 7,
                    "SECUTOR.base_atk": 8,
                    "NET_THROW.sta_cost": 6,
                    "SHIELD_BASH.cooldown_turns": 3,
                    "COMBAT_CONTROLS.recover_bonus_stamina": 4,
                    "MATCHUP.RET_STARTER_vs_RET_STARTER.global_damage_multiplier": 0.9,
                },
                tmp_dir=Path(td) / "cand",
            )

            classes = self._read_json(candidate_dir, "classes.json")["entries"]
            skills = self._read_json(candidate_dir, "skills.json")["entries"]
            controls = self._read_json(candidate_dir, "combat_rules.json")["entries"]["COMBAT_CONTROLS"]
            matchup = self._read_json(candidate_dir, "matchup_modifiers.json")["entries"]["RET_STARTER_vs_RET_STARTER"]

            self.assertEqual(classes["RETIARIUS"]["base_atk"], 7)
            self.assertEqual(classes["SECUTOR"]["base_atk"], 8)
            self.assertEqual(skills["NET_THROW"]["sta_cost"], 6)
            self.assertEqual(skills["SHIELD_BASH"]["cooldown_turns"], 3)
            self.assertEqual(controls["recover_bonus_stamina"], 4)
            self.assertEqual(matchup["global_damage_multiplier"], 0.9)

    def test_apply_params_keeps_backward_compatible_keys(self) -> None:
        defs_dir = Path("data/definitions")
        with tempfile.TemporaryDirectory() as td:
            candidate_dir = _apply_params(
                defs_dir=defs_dir,
                params={
                    "SECUTOR.base_def": 6,
                    "SHIELD_BASH.flat_damage": 1,
                    "RECOVER.sta_cost": 0,
                },
                tmp_dir=Path(td) / "cand",
            )
            classes = self._read_json(candidate_dir, "classes.json")["entries"]
            skills = self._read_json(candidate_dir, "skills.json")["entries"]
            self.assertEqual(classes["SECUTOR"]["base_def"], 6)
            self.assertEqual(skills["SHIELD_BASH"]["flat_damage"], 1)
            self.assertEqual(skills["RECOVER"]["sta_cost"], 0)

    def test_apply_params_rejects_unknown_field(self) -> None:
        defs_dir = Path("data/definitions")
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(ValueError, "Unknown field"):
                _apply_params(
                    defs_dir=defs_dir,
                    params={"RETIARIUS.not_a_real_field": 1},
                    tmp_dir=Path(td) / "cand",
                )


if __name__ == "__main__":
    unittest.main()
