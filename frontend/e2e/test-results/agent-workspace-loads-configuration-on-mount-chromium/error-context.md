# Page snapshot

```yaml
- generic [ref=e3]:
  - banner [ref=e4]:
    - generic [ref=e6]:
      - generic [ref=e7]:
        - heading "🏛️ Daedalus - Master Architect" [level=1] [ref=e8]
        - paragraph [ref=e9]: Generate detailed execution plans from codebase analysis
      - generic [ref=e10]:
        - button "Initialize agent session" [ref=e11] [cursor=pointer]: Initialize Session
        - combobox "Agent Mode" [ref=e12] [cursor=pointer]:
          - option "Daedalus (Planning)" [selected]
          - option "Sisyphus (Execution)"
        - button "Toggle configuration panel" [active] [ref=e13] [cursor=pointer]: ⚙️
        - button "User preferences" [ref=e14] [cursor=pointer]: 👤
  - main [ref=e15]:
    - complementary [ref=e16]:
      - status [ref=e18]: Thinking...
    - generic [ref=e21]:
      - generic [ref=e22]:
        - generic [ref=e23]: Goal
        - textbox "Goal" [ref=e24]:
          - /placeholder: Describe what you want to accomplish (e.g., 'Add user authentication system')...
      - generic [ref=e25]:
        - text: Codebase Path
        - generic [ref=e26]:
          - textbox "Codebase Path" [ref=e27]:
            - /placeholder: /path/to/your/codebase
          - button "Browse" [ref=e28]
      - generic [ref=e29]:
        - generic [ref=e30]: Context Hint (Optional)
        - textbox "Context Hint (Optional)" [ref=e31]:
          - /placeholder: E.g., 'Look at existing authentication patterns'
        - generic [ref=e32]: Optional hint to guide the analysis
      - generic [ref=e33]:
        - button "Generate Execution Plan" [disabled] [ref=e34]
        - button "Reset" [ref=e35] [cursor=pointer]
```