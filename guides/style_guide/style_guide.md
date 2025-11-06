# Elixir Style Guide

## Philosophy

This guide reflects principles for building maintainable, scalable Elixir systems across consulting engagements. Guidelines are marked as **MUST** (strict requirement) or **PREFER** (strong recommendation with context-dependent flexibility).

## Elixir Anti-Patterns

Review the [Elixir Anti-Patterns](https://hexdocs.pm/elixir/main/what-anti-patterns.html) to avoid.

## AI Prompt

Use the following AI prompt to generate consistent guidelines:

```markdown
# Generate Single Elixir Style Guideline

You are creating a standalone guideline for an Elixir Style Guide.

## Output Format:

**[MUST/PREFER]** [brief imperative statement].

\```elixir
# Good
[example code showing correct approach]

# Avoid / Wrong
[example code showing incorrect approach]
\```

**Rationale:** [1-2 sentences explaining WHY this guideline exists - focus on impact]

---

## Rules:

1. **Enforcement Level**:
   - `**MUST**` = strict requirement (correctness, security, data integrity)
   - `**PREFER**` = strong recommendation (readability, maintainability, performance)

2. **Statement**:
   - Brief imperative command (5-15 words)
   - Specific and actionable
   - No generic advice

3. **Code Examples**:
   - Always include both "Good" and "Avoid"/"Wrong"
   - Use "Avoid" for suboptimal code
   - Use "Wrong" for code that causes bugs/errors
   - Keep concise (2-6 lines per example)
   - Use realistic Elixir/Phoenix/Ecto domain names

4. **Rationale**:
   - 1-2 sentences maximum
   - Focus on: readability, performance, correctness, or maintainability
   - Be specific about consequences
   - Use active voice and strong verbs

5. **End with**: Three dashes (`---`) on new line

## Your Task:

Transform this input into a properly formatted guideline:

**INPUT:**
[Paste code example or description here]

**Generate guideline following the exact format above in a single markdown snippet for copy and paste ease.**

```
