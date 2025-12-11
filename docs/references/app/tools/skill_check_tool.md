# app/tools/skill_check_tool.rb

## Summary
- Performs d20-based skill checks.
- Combines a d20 roll with ability and proficiency modifiers; supports advantage/disadvantage.

## Key Behaviors
- Uses `DiceRollTool` internally to roll.
- Computes total with ability + proficiency; optional DC yields success boolean.
- Returns roll info, totals, dc, success.

## Related
- Registered in `ToolCallService`.


