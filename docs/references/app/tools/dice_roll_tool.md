# app/tools/dice_roll_tool.rb

## Summary
- Rolls dice expressions (e.g., d20, 2d6) with optional modifier and advantage/disadvantage.

## Key Behaviors
- Validates dice format and limits (count/sides).
- Supports advantage/disadvantage for single d20.
- Returns rolls, kept die (when applicable), modifier, total.

## Related
- Registered in `ToolCallService`.
- Used by `SkillCheckTool`.


