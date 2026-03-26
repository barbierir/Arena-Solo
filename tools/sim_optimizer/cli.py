from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .optimize import optimize
from .simulate import PRESETS, compare_variants, run_batch, run_suite
from .validate import export_validation_csv, export_validation_json, validate_against_godot_logs


def _write_output(payload: dict, output: str | None) -> None:
    text = json.dumps(payload, indent=2)
    if output:
        Path(output).write_text(text, encoding="utf-8")
        print(f"Wrote {output}")
    else:
        print(text)


def _load_json(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _print_matchup_report(name: str, payload: dict[str, Any]) -> None:
    print(f"\n=== {name} ===")
    print("Core Metrics")
    print(
        "  runs={runs} | win% A={wa:.2f} B={wb:.2f} draw={wd:.2f} | turns avg={ta:.2f} med={tm:.2f} min={tmin} max={tmax}".format(
            runs=payload.get("total_runs", 0),
            wa=payload.get("win_rates", {}).get("attacker_pct", 0.0),
            wb=payload.get("win_rates", {}).get("defender_pct", 0.0),
            wd=payload.get("win_rates", {}).get("draw_pct", 0.0),
            ta=payload.get("turn_stats", {}).get("average", 0.0),
            tm=payload.get("turn_stats", {}).get("median", 0.0),
            tmin=payload.get("turn_stats", {}).get("min", 0),
            tmax=payload.get("turn_stats", {}).get("max", 0),
        )
    )

    apf = payload.get("action_usage_per_fighter", {})
    cpm = payload.get("combat_pattern_metrics", {})
    print("Action Usage")
    print(
        "  attacker: bash={:.2f} net={:.2f} recover={:.2f} | defender: bash={:.2f} net={:.2f} recover={:.2f}".format(
            apf.get("attacker", {}).get("shield_bash", 0.0),
            apf.get("attacker", {}).get("net_throw", 0.0),
            apf.get("attacker", {}).get("recover", 0.0),
            apf.get("defender", {}).get("shield_bash", 0.0),
            apf.get("defender", {}).get("net_throw", 0.0),
            apf.get("defender", {}).get("recover", 0.0),
        )
    )
    print(
        "  stuns={:.2f} stun_lost_turns={:.2f} entangled={:.2f} off_balance_used={:.2f} focused_used={:.2f} crits={:.2f} misses={:.2f}".format(
            cpm.get("avg_stuns_applied", 0.0),
            cpm.get("avg_turns_lost_to_stun", 0.0),
            cpm.get("avg_entangled_applications", 0.0),
            cpm.get("avg_off_balance_consumptions", 0.0),
            cpm.get("avg_focused_consumptions", 0.0),
            cpm.get("avg_crit_count", 0.0),
            cpm.get("avg_miss_count", 0.0),
        )
    )

    patho = payload.get("pathology", {})
    print("Pathology")
    print(
        "  2+ stun chain={:.2f}% | stun-heavy={:.2f}% | long={:.2f}% | quick={:.2f}% | high-HP winner={:.2f}%".format(
            patho.get("fights_with_2plus_consecutive_stun_losses_pct", 0.0),
            patho.get("fights_with_stun_heavy_side_pct", 0.0),
            patho.get("fights_exceeding_long_threshold_pct", 0.0),
            patho.get("fights_at_or_below_quick_threshold_pct", 0.0),
            patho.get("fights_with_high_hp_winner_pct", 0.0),
        )
    )


def _merge_thresholds(args: argparse.Namespace) -> dict[str, float]:
    thresholds = {}
    if args.long_fight_threshold is not None:
        thresholds["long_fight_turns"] = args.long_fight_threshold
    if args.quick_fight_threshold is not None:
        thresholds["quick_fight_turns"] = args.quick_fight_threshold
    if args.stun_lock_threshold is not None:
        thresholds["stun_turns_threshold"] = args.stun_lock_threshold
    return thresholds


def _apply_preset(args: argparse.Namespace) -> None:
    if not args.preset:
        return
    preset = PRESETS[args.preset]
    if args.runs is None:
        args.runs = preset["runs"]
    if args.max_turns is None:
        args.max_turns = preset["max_turns"]


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Standalone combat simulator and optimizer for GLADIUS")
    p.add_argument("--definitions-dir", default="data/definitions", help="Path to runtime combat definitions")

    sub = p.add_subparsers(dest="command", required=True)

    sim = sub.add_parser("simulate", help="Run one matchup in batch mode")
    sim.add_argument("--attacker", required=True)
    sim.add_argument("--defender", required=True)
    sim.add_argument("--runs", type=int)
    sim.add_argument("--seed", type=int, default=1001)
    sim.add_argument("--max-turns", type=int)
    sim.add_argument("--preset", choices=sorted(PRESETS.keys()), default="standard")
    sim.add_argument("--modifier-overrides", help="JSON file with matchup modifier overrides")
    sim.add_argument("--long-fight-threshold", type=float)
    sim.add_argument("--quick-fight-threshold", type=float)
    sim.add_argument("--stun-lock-threshold", type=float)
    sim.add_argument("--verbose", action="store_true", help="Print active matchup modifiers")
    sim.add_argument("--no-matchup-modifiers", action="store_true", help="Disable matchup modifiers")
    sim.add_argument("--output")

    suite = sub.add_parser("suite", help="Run standard matchup suite")
    suite.add_argument("--runs", type=int)
    suite.add_argument("--seed", type=int, default=6100)
    suite.add_argument("--max-turns", type=int)
    suite.add_argument("--preset", choices=sorted(PRESETS.keys()), default="standard")
    suite.add_argument("--modifier-overrides")
    suite.add_argument("--long-fight-threshold", type=float)
    suite.add_argument("--quick-fight-threshold", type=float)
    suite.add_argument("--stun-lock-threshold", type=float)
    suite.add_argument("--verbose", action="store_true")
    suite.add_argument("--no-matchup-modifiers", action="store_true")
    suite.add_argument("--output")

    cmp_cmd = sub.add_parser("compare", help="Run matchup suite for multiple variants and compare deltas")
    cmp_cmd.add_argument("--config", required=True, help="JSON config with variants[]")
    cmp_cmd.add_argument("--runs", type=int)
    cmp_cmd.add_argument("--seed", type=int, default=6100)
    cmp_cmd.add_argument("--max-turns", type=int)
    cmp_cmd.add_argument("--preset", choices=sorted(PRESETS.keys()), default="standard")
    cmp_cmd.add_argument("--long-fight-threshold", type=float)
    cmp_cmd.add_argument("--quick-fight-threshold", type=float)
    cmp_cmd.add_argument("--stun-lock-threshold", type=float)
    cmp_cmd.add_argument("--verbose", action="store_true")
    cmp_cmd.add_argument("--output")

    val = sub.add_parser("validate", help="Validate simulator matchup metrics against Godot text batch reports")
    val.add_argument("--godot-log-dir", default="batch_reports", help="Directory with Godot .txt batch reports")
    val.add_argument("--runs", type=int, default=1000)
    val.add_argument("--seed", type=int, default=6100)
    val.add_argument("--max-turns", type=int, default=128)
    val.add_argument("--min-sample-size", type=int, default=1, help="Hide drift rankings under this Godot fight count")
    val.add_argument("--top-drift", type=int, default=5, help="Number of highest-drift matchups to print")
    val.add_argument("--sample-logs", action="store_true", help="Attach representative simulator samples (short/median/long)")
    val.add_argument("--verbose", action="store_true", help="Print active matchup modifiers")
    val.add_argument("--no-matchup-modifiers", action="store_true", help="Disable matchup modifiers")
    val.add_argument("--export-csv", help="Optional CSV export path")
    val.add_argument("--export-json", help="Optional JSON export path")
    val.add_argument("--output")

    opt = sub.add_parser("optimize", help="Search a bounded parameter space for balance candidates")
    opt.add_argument("--trials", type=int, default=0, help="0 means exhaustive grid")
    opt.add_argument("--runs", type=int, default=500)
    opt.add_argument("--seed", type=int, default=4242)
    opt.add_argument("--max-turns", type=int, default=128)
    opt.add_argument("--param-config")
    opt.add_argument("--verbose", action="store_true", help="Print active matchup modifiers")
    opt.add_argument("--no-matchup-modifiers", action="store_true", help="Disable matchup modifiers")
    opt.add_argument("--output")

    return p


def main() -> None:
    args = build_parser().parse_args()
    defs_dir = Path(args.definitions_dir)

    if args.command == "simulate":
        _apply_preset(args)
        thresholds = _merge_thresholds(args)
        payload = run_batch(
            defs_dir,
            args.attacker,
            args.defender,
            args.seed,
            args.runs,
            args.max_turns,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            matchup_modifier_overrides=_load_json(args.modifier_overrides),
            pathology_thresholds=thresholds,
            verbose=args.verbose,
        )
        _print_matchup_report(f"{args.attacker}_vs_{args.defender}", payload)
        _write_output(payload, args.output)
    elif args.command == "suite":
        _apply_preset(args)
        thresholds = _merge_thresholds(args)
        payload = run_suite(
            defs_dir,
            runs=args.runs,
            max_turns=args.max_turns,
            base_seed=args.seed,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            matchup_modifier_overrides=_load_json(args.modifier_overrides),
            pathology_thresholds=thresholds,
            verbose=args.verbose,
        )
        for matchup_name, matchup_payload in payload.items():
            _print_matchup_report(matchup_name, matchup_payload)
        _write_output(payload, args.output)
    elif args.command == "compare":
        _apply_preset(args)
        thresholds = _merge_thresholds(args)
        config = _load_json(args.config)
        payload = compare_variants(
            definitions_dir=defs_dir,
            variants=list(config.get("variants", [])),
            runs=args.runs,
            max_turns=args.max_turns,
            base_seed=args.seed,
            pathology_thresholds=thresholds,
            verbose=args.verbose,
        )
        for variant_name, suite_payload in payload.get("variants", {}).items():
            print(f"\n######## Variant: {variant_name} ########")
            for matchup_name, matchup_payload in suite_payload.items():
                _print_matchup_report(matchup_name, matchup_payload)

        print("\nComparison Deltas")
        for delta_key, by_matchup in payload.get("comparison", {}).get("deltas", {}).items():
            print(f"  {delta_key}")
            for matchup_key, deltas in by_matchup.items():
                print(
                    "    {}: win_shift={:+.2f} avg_turn_shift={:+.2f} stun_lock_shift={:+.2f}".format(
                        matchup_key,
                        float(deltas.get("attacker_winrate_shift", 0.0)),
                        float(deltas.get("avg_turn_shift", 0.0)),
                        float(deltas.get("stun_lock_shift", 0.0)),
                    )
                )
        _write_output(payload, args.output)
    elif args.command == "validate":
        payload = validate_against_godot_logs(
            defs_dir,
            Path(args.godot_log_dir),
            args.runs,
            args.max_turns,
            args.seed,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            verbose=args.verbose,
            min_sample_size=args.min_sample_size,
            top_drift_count=args.top_drift,
            sample_logs=args.sample_logs,
        )
        print(f"Parsed reports: {payload.get('parsed_reports', 0)} | overall calibration: {payload.get('overall_calibration_score')}")
        print("Top drift matchups:")
        for item in payload.get("top_drift_matchups", []):
            diag = payload.get("matchups", {}).get(item.get("matchup", ""), {}).get("parser_diagnostics", {})
            action_src = diag.get("action_usage_source")
            print(
                "  {m}: score={s} severity={sev} fights={f} action_source={src}".format(
                    m=item.get("matchup", ""),
                    s=item.get("calibration_score"),
                    sev=item.get("drift_severity"),
                    f=item.get("total_fights", 0),
                    src=action_src,
                )
            )
        if args.export_csv:
            export_validation_csv(payload, Path(args.export_csv))
            print(f"Wrote {args.export_csv}")
        if args.export_json:
            export_validation_json(payload, Path(args.export_json))
            print(f"Wrote {args.export_json}")
        _write_output(payload, args.output)
    elif args.command == "optimize":
        payload = optimize(
            defs_dir,
            args.trials,
            args.runs,
            args.max_turns,
            args.seed,
            Path(args.param_config) if args.param_config else None,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            verbose=args.verbose,
        )
        _write_output(payload, args.output)


if __name__ == "__main__":
    main()
