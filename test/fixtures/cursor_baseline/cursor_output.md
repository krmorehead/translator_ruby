# Cursor Baseline Output

> **Note**: This file should be populated with Cursor's actual research output.
> Run the prompt from `research_prompt.md` against the example_codebase and paste the results here.

## Placeholder

This is a placeholder. To complete the baseline comparison test:

1. Open `test/fixtures/example_codebase` in Cursor
2. Run the research prompt from `research_prompt.md`
3. Replace this content with Cursor's actual output

---

## Example Expected Content

The actual Cursor output should include analysis of:

### Calculator Class
- Located at `lib/calculator.rb`
- Provides basic arithmetic operations: add, subtract, multiply, divide
- Handles division by zero with custom error class
- Includes percentage and average calculations

### Formatter Class
- Located at `lib/formatter.rb`
- Depends on Calculator for some operations (percentage_change)
- Provides number formatting: currency, percent, separators
- Uses dependency injection for Calculator instance

### MathService
- Located at `app/services/math_service.rb`
- Combines Calculator and Formatter for high-level operations
- Methods: calculate_total, calculate_statistics, apply_discount, compare_values, compound_interest
- Follows service object pattern

### Dependencies
```
MathService
├── Calculator (direct)
└── Formatter
    └── Calculator (indirect)
```

### Design Patterns
- Dependency Injection (Formatter accepts Calculator)
- Service Object (MathService encapsulates business logic)
- Composition over Inheritance (MathService composes Calculator + Formatter)

