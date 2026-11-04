# lane-regress — T52 "never again"

Started 4 Nov 17:43. Worktree ~/repos/fk-regress, branch lane-regress. Tests only: product bugs go below for main.

## What this lane delivers
- tools/regress/README.md: the list — every ledger item r24→r27 and every row of the master's trace → its check (or: gone / record / manual / open T..).
- tools/regress/items.py: reads that list; check (held by tests/regress/test_list.sh) · count · blame LOG.
- tests/regress/test_*.sh: the stand-in checks that did not exist yet.
- tools/regress/*.sh: the headless ones that did not exist yet.
- tools/prepush.sh, tools/selftest.sh's section.

## State (keep current)
- [ ] items.py + test_list.sh
- [ ] the list complete
- [ ] the new checks, each proven to fail on the old behaviour
- [ ] wiring: selftest, prepush
- [ ] whole suite + regress on HEAD
