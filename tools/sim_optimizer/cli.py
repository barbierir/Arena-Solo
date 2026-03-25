from __future__ import annotations

import argparse
import json
from pathlib import Path

from .optimize import optimize
from .simulate import run_batch
from .validate import compare_suite_to_references


def _write_output(payload: dict, output: str | None) -> None:
    text = json.dumps(payload, indent=2)
    if output:
        Path(output).write_text(text, encoding="utf-8")
        print(f"Wrote {output}")
    else:
        print(text)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Standalone combat simulator and optimizer for GLADIUS")
    p.add_argument("--definitions-dir", default="data/definitions", help="Path to runtime combat definitions")

    sub = p.add_subparsers(dest="command", required=True)

    sim = sub.add_parser("simulate", help="Run one matchup in batch mode")
    sim.add_argument("--attacker", required=True)
    sim.add_argument("--defender", required=True)
    sim.add_argument("--runs", type=int, default=1000)
    sim.add_argument("--seed", type=int, default=1001)
    sim.add_argument("--max-turns", type=int, default=128)
    sim.add_argument("--verbose", action="store_true", help="Print active matchup modifiers")
    sim.add_argument("--no-matchup-modifiers", action="store_true", help="Disable matchup modifiers")
    sim.add_argument("--output")

    val = sub.add_parser("validate", help="Compare Python aggregate output to Godot batch report JSON")
    val.add_argument("--reference-dir", default="batch_reports")
    val.add_argument("--runs", type=int, default=1000)
    val.add_argument("--seed", type=int, default=6100)
    val.add_argument("--max-turns", type=int, default=128)
    val.add_argument("--verbose", action="store_true", help="Print active matchup modifiers")
    val.add_argument("--no-matchup-modifiers", action="store_true", help="Disable matchup modifiers")
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
        payload = run_batch(
            defs_dir,
            args.attacker,
            args.defender,
            args.seed,
            args.runs,
            args.max_turns,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            verbose=args.verbose,
        )
        _write_output(payload, args.output)
    elif args.command == "validate":
        payload = compare_suite_to_references(
            defs_dir,
            Path(args.reference_dir),
            args.runs,
            args.max_turns,
            args.seed,
            enable_matchup_modifiers=not args.no_matchup_modifiers,
            verbose=args.verbose,
        )
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
