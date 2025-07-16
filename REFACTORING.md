# Flo Refactoring Plan - Based on Fish Language & Completions Documentation

## Language Improvements

### 1. Modern Variable Handling
- Replace `test -n "$var"` with `set -q var` for existence checks
- Use `$pipestatus` for better pipeline error handling
- Leverage negative array indexing (`$array[-1]` for last element)
- Use array slicing (`$array[2..-2]`)

### 2. String Manipulation
- Replace `sed` with Fish's `string` builtin:
  - `string replace` instead of `sed s///`
  - `string match` instead of `grep`
  - `string split` instead of `cut`
  - `string trim` for whitespace removal

### 3. Path Operations
- Use `**` for recursive directory matching
- Replace `find` with Fish glob patterns where possible

### 4. Error Handling
- Properly check `$status` after each command
- Use `$pipestatus` for pipeline error checking
- Implement proper exit codes with `return`

### 5. Function Improvements
- Add `--description` to all functions
- Use `argparse` for robust argument parsing
- Leverage function autoloading

### 6. Modern Conditionals
- Replace `test` with `[` syntax where clearer
- Use `and` and `or` combiners effectively
- Leverage Fish's command-based conditionals

### 7. Performance Optimizations
- Use local variables (`set -l`) in functions
- Avoid command substitution in loops
- Cache expensive operations
- Use lazy function loading

## Completions Improvements

### 1. Use Built-in Helpers
- `__fish_complete_directories` for directory completions
- `__fish_print_hostnames` for remote completions
- Other built-in completion functions

### 2. Advanced Conditions
- Use `--condition` flag for complex logic
- Create custom condition functions
- Optimize condition checking order

### 3. Dynamic Completions
- Cache expensive completions (like `gh issue list`)
- Use background refresh for dynamic data
- Implement smart caching with TTL

### 4. Better Descriptions
- Add contextual descriptions
- Use consistent formatting
- Include keyboard shortcuts in descriptions

### 5. Exclusive Options
- Properly use `-x` for mutually exclusive options
- Group related options
- Use `-r` for required arguments

## Specific Refactoring Tasks

### High Priority
1. Replace all `sed` usage with `string` commands
2. Implement `argparse` in main functions
3. Add proper `$pipestatus` checking
4. Use `set -q` instead of `test -n`

### Medium Priority
1. Add `--description` to all functions
2. Implement negative array indexing
3. Use `**` for recursive operations
4. Cache expensive completions

### Low Priority
1. Add event handlers for integration
2. Optimize function loading
3. Create vendor completions package
4. Add keyboard shortcut hints