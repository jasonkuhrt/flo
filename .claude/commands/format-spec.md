---
description: Apply semantic formatting to specification.md
allowed-tools: Read, Edit, MultiEdit
---

Apply comprehensive semantic formatting to `docs/development/specification.md` with these specific rules:

## Cross-References & Linking
- **Internal references**: Link all mentions of commands, exceptions, patterns, and design goals
  - `flo end` → `[flo end](#flo-end)`
  - `[not_git_project]` → `[not_git_project](#not-in-git-project-not_git_project)`
  - Design goals → `[Contextual Over Explicit](#contextual-over-explicit)`
- **Exception codes**: Ensure all exception references link to their definitions
- **Pattern references**: Link pattern mentions to their definitions

## Consistency & Terminology
- **Standardize terms**: Use consistent terminology throughout
  - "flow" vs "Flow" - be consistent with capitalization
  - "worktree" vs "work tree" - pick one spelling
  - "GitHub" vs "Github" - use official capitalization
- **Flag formatting**: Ensure all flags use backticks: `--flag-name`
- **Command formatting**: Use consistent formatting for command examples

## Structure & Parallel Construction
- **Section headers**: Ensure parallel structure in similar sections
- **Lists**: Use consistent bullet styles and formatting
- **Tables**: Ensure consistent column alignment and content structure
- **Examples**: Follow same format pattern across all commands

## Clarity & Precision
- **Replace vague language**: "thing" → specific term, "stuff" → precise description
- **Complete sentences**: Ensure all bullet points are complete thoughts
- **Clear action words**: Use precise verbs (create, delete, show, prompt)
- **Consistent voice**: Use same grammatical person throughout

## Completeness Validation
- **Flag completeness**: Ensure all mentioned flags have definitions
- **Exception coverage**: Verify all error scenarios have exception codes
- **Example accuracy**: Ensure examples match current flag definitions
- **Missing links**: Flag any references that should be linked but aren't

## What NOT to Change
- **Core functionality**: Don't alter intended behavior or add new features
- **Design goals**: Don't modify the fundamental design principles
- **Exception codes**: Don't change existing exception code names
- **Command names**: Don't rename commands or flags

## Process
1. Read the entire specification.md file first
2. Apply formatting rules systematically
3. Verify all internal links work
4. Check for consistency across similar sections
5. Flag any incomplete or unclear sections for human review

Focus on making the spec more maintainable, consistent, and easier to navigate while preserving all intended functionality.