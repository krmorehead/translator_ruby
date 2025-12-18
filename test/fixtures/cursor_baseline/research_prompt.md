# Cursor Baseline Research Prompt

Use this prompt with Cursor to generate a baseline research output that can be compared against the CodebaseResearcher worker.

## Instructions

1. Open the `test/fixtures/example_codebase` directory in Cursor
2. Use the following prompt with Cursor's research/chat feature
3. Save the output to `cursor_output.md` in this directory

## Prompt

```
Research the example_codebase and generate per-file documentation for each relevant file.

Research questions:
1. How does the Calculator class work? What operations does it support?
2. What is the relationship between Formatter and Calculator?
3. How does MathService use both Calculator and Formatter?
4. What are the dependencies between these classes?
5. What design patterns are used in this codebase?

For each file that helps answer these questions, generate documentation including:
- A brief summary of the file's purpose
- A mermaid diagram showing external file references/dependencies
- A mermaid diagram showing method architecture (which methods call which)
- A summary of each method's purpose

Also provide:
- A base_references.md style tree diagram listing all documented files with short descriptions
- A synthesis summary answering the original research questions

Format all output for AI consumption.
```

## Expected Output Structure

The output should include:

### Per-File Documentation (for each relevant file)
- `lib/calculator.md` - Calculator class documentation
- `lib/formatter.md` - Formatter class documentation
- `app/services/math_service.md` - MathService documentation

### Each per-file doc should contain:
```markdown
# {file_path}

## Summary
{brief_summary}

## Source
- [View Code]({relative_link})

## External References
```mermaid
graph LR
    {dependency_diagram}
```

## Method Architecture
```mermaid
flowchart TD
    {method_call_diagram}
```

## Methods
### {method_name}
{method_summary}
```

### Directory Tree (base_references.md style)
```
lib/
├── calculator.rb    # Math operations (add, subtract, multiply, divide)
└── formatter.rb     # Number formatting using Calculator

app/services/
└── math_service.rb  # Combines Calculator and Formatter
```

### Synthesis Summary
- Overview of the codebase structure
- How Calculator, Formatter, and MathService relate
- Dependency relationships
- Design patterns identified

