# Checkpoint Decision Table

## After running the four checkpoint questions, match the strongest signal:

| Signal | Action |
|--------|--------|
| Quality solid, upcoming tasks clean | Continue. Note insights for upcoming tasks. |
| Upcoming tasks have unmet preconditions | Insert a preparation task before continuing. |
| Integration has rough edges | Dispatch focused cleanup subagent before building more on top. |
| Quality trend declining | Identify cause (shortcuts, missing abstraction, growing complexity). Fix cause, not symptom. |
| Early tasks revealed better patterns | Update remaining tasks with what you've learned. Share revision with user if substantial. |
| Upcoming tasks will be fragile given current state | Strengthen foundation first — tests, shared code, fix wobbly bits. |
| Trajectory is off | Stop. Present what you've learned, propose course correction. |

## Example checkpoint output

```
CHECKPOINT after tasks 1-3 of 7:

Forward-look: Tasks 4-5 both need a date parsing utility that doesn't exist yet.
  The plan has each task implementing its own parsing. Better to extract a shared
  utility now.
  → ACTION: Insert prep task to create date parsing module with tests.

Integration: Tasks 1-3 integrate cleanly. Data flows correctly through the pipeline.
  → No action needed.

Quality trend: Task 3 review was quick (1 round). Task 2 had 2 rounds due to
  missing error handling — but that was a plan gap, not a pattern yet.
  → Watch for it in task 4.

Learning: The API returns paginated results. Plan didn't account for this.
  Tasks 5-7 assume single-response queries.
  → ACTION: Update tasks 5-7 to handle pagination. Flag to user.
```
