# Football RPG — first incremental slice

The manager already owns an immutable, replay-validated career journal and player identities.
RPG progression is a derived read model, not a second save file or a change to the simulation.

- 100 XP per recorded start, plus 25 XP for a recorded shooting or shape session.
- Every 500 XP advances one level, starting at level 1.
- A benched player receives no XP. Standard and recovery starts grant only participation XP.
- Legacy rounds excluded from the existing development ledger remain excluded.
- No claims about individual goals, passes, tackles or minutes from simulated fixtures.
- Existing attack/defense growth, scores, training and journal schema remain unchanged.

Follow-up slices: player profile UI with level, XP and clear provenance; role-specific
specializations and explicit choices only after a versioned journal contract; then
bounded simulation effects, morale/chemistry, scouting, academy, transfers and career
legacy. Keep Godot integration on hold until the explicit match-result contract is ready.
No new infrastructure or dependencies. Balance numbers are initial design defaults.
