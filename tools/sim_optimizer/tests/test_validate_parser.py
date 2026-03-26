from __future__ import annotations

import tempfile
import textwrap
import unittest
from pathlib import Path

from tools.sim_optimizer.validate import _action_drift, _aggregate_real_metrics, parse_godot_text_report


class ValidateParserTests(unittest.TestCase):
    def _write_report(self, folder: Path, name: str, content: str) -> Path:
        path = folder / name
        path.write_text(textwrap.dedent(content).strip() + "\n", encoding="utf-8")
        return path

    def test_parse_new_format_mixed_matchup_preserves_side_actions(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = self._write_report(
                Path(td),
                "ret_vs_sec.txt",
                """
                GLADIUS Batch Report
                Inputs:
                - A: Retiarius (RET_STARTER)
                - B: Secutor (SEC_STARTER)
                - Simulations: 10
                Summary:
                - A wins: 4 (40.0%)
                - B wins: 6 (60.0%)
                - Draws/Unresolved: 0
                - Turns avg/min/max: 12.0 / 8 / 20
                Terminal Conditions:
                - HP_ZERO: 10
                Ability Usage (all fights):
                - NOTE: Combined across attacker + defender (legacy aggregate).
                - BASIC_ATTACK: 40
                - NET_THROW: 10
                - SHIELD_BASH: 12
                Status Applications (all fights):
                - NOTE: Combined across attacker + defender (legacy aggregate).
                - ENTANGLED: 8
                Per-Fighter Diagnostics:
                Attacker:
                  A (Retiarius):
                  - Build ID: RET_STARTER
                  - W/L: 4 / 6
                  - Hit/Miss: 30 / 5
                  - End state in wins (HP/STA): 25.0 / 5.0
                  - Ability usage:
                  - BASIC_ATTACK: 22
                  - NET_THROW: 10
                  - RECOVER: 5
                  - Status applications:
                  - ENTANGLED: 8
                  - Status uptime turns:
                  - FOCUSED: 7
                Defender:
                  B (Secutor):
                  - Build ID: SEC_STARTER
                  - W/L: 6 / 4
                  - Hit/Miss: 33 / 4
                  - End state in wins (HP/STA): 28.0 / 6.0
                  - Ability usage:
                  - BASIC_ATTACK: 18
                  - SHIELD_BASH: 12
                  - RECOVER: 4
                  - Status applications:
                  - STUNNED: 6
                  - Status uptime turns:
                  - OFF_BALANCE: 9
                Extended Aggregate Metrics:
                - Miss count (A/B): 5 / 4
                """,
            )
            parsed = parse_godot_text_report(path)
            self.assertIsNotNone(parsed)
            assert parsed is not None
            self.assertEqual(parsed["fighters"]["attacker"]["ability_usage_counts"].get("NET_THROW"), 10)
            self.assertEqual(parsed["fighters"]["defender"]["ability_usage_counts"].get("SHIELD_BASH"), 12)

            aggregate = _aggregate_real_metrics([parsed])["RET_STARTER_vs_SEC_STARTER"]
            self.assertEqual(aggregate["action_usage_data_quality"]["source"], "per_fighter")
            self.assertEqual(aggregate["action_usage_per_fighter"]["attacker"]["shield_bash"], 0.0)
            self.assertEqual(aggregate["action_usage_per_fighter"]["defender"]["net_throw"], 0.0)

    def test_legacy_combined_actions_do_not_duplicate_to_both_sides(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = self._write_report(
                Path(td),
                "legacy.txt",
                """
                GLADIUS Batch Report
                Inputs:
                - A: Secutor (SEC_STARTER)
                - B: Retiarius (RET_STARTER)
                - Simulations: 10
                Summary:
                - A wins: 5 (50.0%)
                - B wins: 5 (50.0%)
                - Draws/Unresolved: 0
                - Turns avg/min/max: 11.0 / 7 / 18
                Terminal Conditions:
                - HP_ZERO: 10
                Ability Usage (all fights):
                - BASIC_ATTACK: 35
                - SHIELD_BASH: 14
                - NET_THROW: 8
                Status Applications (all fights):
                - ENTANGLED: 7
                Per-Fighter Diagnostics:
                A (Secutor):
                - Build ID: SEC_STARTER
                - W/L: 5 / 5
                - Hit/Miss: 25 / 5
                B (Retiarius):
                - Build ID: RET_STARTER
                - W/L: 5 / 5
                - Hit/Miss: 25 / 5
                Extended Aggregate Metrics:
                - Miss count (A/B): 5 / 5
                """,
            )
            parsed = parse_godot_text_report(path)
            assert parsed is not None
            aggregate = _aggregate_real_metrics([parsed])["SEC_STARTER_vs_RET_STARTER"]
            self.assertEqual(aggregate["action_usage_data_quality"]["source"], "legacy_combined_only")
            self.assertIsNone(aggregate["action_usage_per_fighter"]["attacker"]["shield_bash"])
            self.assertIsNone(aggregate["action_usage_per_fighter"]["defender"]["net_throw"])
            sim = {
                "action_usage_per_fighter": {
                    "attacker": {"shield_bash": 1.4, "net_throw": 0.0, "recover": 0.2},
                    "defender": {"shield_bash": 0.0, "net_throw": 0.8, "recover": 0.3},
                }
            }
            self.assertIsNone(_action_drift(sim, aggregate))

    def test_four_matchup_suite_parses_side_specific_actions(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fixtures = {
                "ret_vs_ret.txt": ("RET_STARTER", "RET_STARTER", 6, 6, 0, 0),
                "sec_vs_sec.txt": ("SEC_STARTER", "SEC_STARTER", 0, 0, 7, 7),
                "ret_vs_sec.txt": ("RET_STARTER", "SEC_STARTER", 8, 0, 0, 9),
                "sec_vs_ret.txt": ("SEC_STARTER", "RET_STARTER", 0, 10, 12, 0),
            }
            parsed_reports = []
            for filename, (a_id, b_id, a_net, b_net, a_bash, b_bash) in fixtures.items():
                parsed_reports.append(
                    parse_godot_text_report(
                        self._write_report(
                            root,
                            filename,
                            f"""
                            GLADIUS Batch Report
                            Inputs:
                            - A: A ({a_id})
                            - B: B ({b_id})
                            - Simulations: 10
                            Summary:
                            - A wins: 5 (50.0%)
                            - B wins: 5 (50.0%)
                            - Draws/Unresolved: 0
                            - Turns avg/min/max: 10.0 / 6 / 14
                            Terminal Conditions:
                            - HP_ZERO: 10
                            Ability Usage (all fights):
                            - BASIC_ATTACK: 30
                            Status Applications (all fights):
                            - ENTANGLED: 2
                            Per-Fighter Diagnostics:
                            Attacker:
                              A (A):
                              - Build ID: {a_id}
                              - W/L: 5 / 5
                              - Hit/Miss: 20 / 4
                              - End state in wins (HP/STA): 20.0 / 4.0
                              - Ability usage:
                              - BASIC_ATTACK: 15
                              - NET_THROW: {a_net}
                              - SHIELD_BASH: {a_bash}
                              - RECOVER: 3
                              - Status applications:
                              - ENTANGLED: 1
                              - Status uptime turns:
                              - FOCUSED: 1
                            Defender:
                              B (B):
                              - Build ID: {b_id}
                              - W/L: 5 / 5
                              - Hit/Miss: 20 / 4
                              - End state in wins (HP/STA): 20.0 / 4.0
                              - Ability usage:
                              - BASIC_ATTACK: 15
                              - NET_THROW: {b_net}
                              - SHIELD_BASH: {b_bash}
                              - RECOVER: 3
                              - Status applications:
                              - ENTANGLED: 1
                              - Status uptime turns:
                              - FOCUSED: 1
                            Extended Aggregate Metrics:
                            - Miss count (A/B): 4 / 4
                            """,
                        )
                    )
                )

            reports = [r for r in parsed_reports if r is not None]
            self.assertEqual(len(reports), 4)
            aggregate = _aggregate_real_metrics(reports)
            self.assertEqual(aggregate["RET_STARTER_vs_SEC_STARTER"]["action_usage_per_fighter"]["attacker"]["shield_bash"], 0.0)
            self.assertEqual(aggregate["RET_STARTER_vs_SEC_STARTER"]["action_usage_per_fighter"]["defender"]["net_throw"], 0.0)
            self.assertEqual(aggregate["SEC_STARTER_vs_RET_STARTER"]["action_usage_per_fighter"]["attacker"]["net_throw"], 0.0)
            self.assertEqual(aggregate["SEC_STARTER_vs_RET_STARTER"]["action_usage_per_fighter"]["defender"]["shield_bash"], 0.0)


if __name__ == "__main__":
    unittest.main()
