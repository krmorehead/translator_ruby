# Cursor Baseline Research Prompt

Use this prompt with Cursor to generate a baseline research output that can be compared against the CodebaseResearcher worker.

## Instructions

1. Open the `test/fixtures/example_codebase` directory in Cursor
2. Use the following prompt with Cursor's research/chat feature
3. Save the output to `cursor_output.md` in this directory

## Prompt

```
Research the example_codebase and explain:

1. How does the Calculator class work? What operations does it support?
2. What is the relationship between Formatter and Calculator?
3. How does MathService use both Calculator and Formatter?
4. What are the dependencies between these classes?
5. What design patterns are used in this codebase?

Provide a comprehensive analysis with code references.
```

## Expected Output Sections

The output should cover:
- Overview of the codebase structure
- Calculator class analysis (methods, error handling)
- Formatter class analysis (dependency on Calculator)
- MathService analysis (composition of Calculator and Formatter)
- Dependency graph
- Design patterns identified

