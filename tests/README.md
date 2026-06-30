# Running the Test Suite

## Requirements

- Godot 4.3 (same version as the project)
- The project must be imported at least once so `.godot/` exists

## Command

Run from the **project root** (the directory containing `project.godot`):

```bash
godot --headless --path . -s tests/unit_tests/TestRunner.gd
```

Exit code `0` means all tests passed; exit code `1` means one or more failures.

## What the tests cover

| File | What it validates |
|------|-------------------|
| `test_unit_database.gd` | `UnitDatabase` exposes all 8 unit types; `create_unit` sets `unit_type` and `team` |
| `test_economy.gd` | `Economy.add_money`, `spend`, and `can_afford` behave correctly |
| `test_outpost_capture.gd` | Calling `_complete_capture` changes the building's team and emits `building_captured` |
| `test_unit_order.gd` | `give_order` sets `current_order` and emits `unit_order_changed` |
| `test_projectile_team.gd` | Projectile's friendly-fire guard prevents damage to same-team bodies |
| `test_match_end.gd` | `GameState.end_match` sets `match_active = false` and records the winning team |

## Sample output (all passing)

```
[PASS] test_unit_database  (17 / 17)
[PASS] test_economy  (7 / 7)
[PASS] test_outpost_capture  (5 / 5)
[PASS] test_unit_order  (4 / 4)
[PASS] test_projectile_team  (3 / 3)
[PASS] test_match_end  (4 / 4)

=== 40 passed, 0 failed ===
```

## Extending the suite

Add a new file in `tests/unit_tests/` that `extends TestBase`, implement `func run(_parent: Node = null) -> void:`, and add a `preload()` entry to the `TESTS` array in `TestRunner.gd`.
