# Example Codebase

A simple Ruby codebase for testing the CodebaseResearcher worker.

## Structure

```
example_codebase/
├── lib/
│   ├── calculator.rb    # Basic arithmetic operations
│   └── formatter.rb     # Number formatting utilities
├── app/
│   └── services/
│       └── math_service.rb  # High-level math service
├── Gemfile
└── README.md
```

## Architecture

The codebase follows a layered architecture:

1. **Calculator** (`lib/calculator.rb`) - Core arithmetic operations
   - Addition, subtraction, multiplication, division
   - Percentage and average calculations
   - Error handling for edge cases

2. **Formatter** (`lib/formatter.rb`) - Number formatting
   - Currency formatting
   - Percentage display
   - Thousand separators
   - Depends on Calculator for some operations

3. **MathService** (`app/services/math_service.rb`) - Application service
   - Combines Calculator and Formatter
   - Provides high-level business operations
   - Formatted output for display

## Dependencies

```
MathService
    ├── Calculator (for arithmetic)
    └── Formatter (for formatting)
          └── Calculator (for percentage calculations)
```

## Usage

```ruby
service = MathService.new
result = service.apply_discount(100.00, 20)
# => { original: "$100.00", discount: "20.0%", savings: "$20.00", final: "$80.00", raw_final: 80.0 }
```

