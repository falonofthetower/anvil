# Anvil Programming Language - Ralph Prompt

## Mission

Build a programming language called **Anvil** optimized for LLM-driven development. The language should be trivially easy for an LLM to write correct code in, and when code is incorrect, the compiler should output structured errors that an LLM can mechanically fix without understanding.

## Core Philosophy

**The compiler is the teacher, the LLM is the student.**

Every compiler error must include a machine-applicable fix. The LLM doesn't need to reason about the error—it applies the suggested patch and re-runs. If the compiler can identify a problem, it must also identify the solution.

## Language Design Constraints

### 1. Unambiguous Grammar
- Context-free grammar (no lookahead beyond 1 token)
- No operator precedence—use explicit parentheses or prefix notation
- No significant whitespace
- Every construct has exactly one syntactic form
- Delimiter-closed blocks (braces or end keywords, not indentation)

### 2. Explicit Types
- No type inference (or only local single-expression inference)
- All function signatures fully typed
- All variable declarations include type
- No implicit coercions between types
- No subtyping—use explicit conversions

### 3. Total Functions
- No partial functions (functions must handle all inputs)
- No null/nil/undefined—use Option[T]
- No exceptions—use Result[T, E]
- Pattern matching must be exhaustive
- Division, array access, etc. return Result types

### 4. Explicit Effects
- Pure functions by default
- IO, mutation, randomness are typed effects
- No hidden state or global variables
- Effect requirements visible in function signature

### 5. Small Surface Area
- Minimal keywords (target: under 25)
- Orthogonal features that compose predictably
- No special cases or syntax sugar initially
- One obvious way to do each thing

## Compiler Requirements

### Structured Error Output

All compiler errors MUST be JSON with this schema:

    {
      "errors": [
        {
          "code": "E001",
          "category": "type_mismatch",
          "severity": "error",
          "message": "Human readable description",
          "doc": "docs/errors/E001_type_mismatch.md",
          "location": {
            "file": "path/to/file.anvil",
            "start": {"line": 42, "column": 15, "offset": 1847},
            "end": {"line": 42, "column": 23, "offset": 1855}
          },
          "context": {
            "function": "add",
            "expression": "add(1, hello_str)",
            "expected_type": "Int",
            "actual_type": "String",
            "argument_position": 2
          },
          "suggestions": [
            {
              "description": "Convert String to Int using parse",
              "confidence": "high",
              "fix": {
                "action": "replace",
                "location": {
                  "start": {"line": 42, "column": 18},
                  "end": {"line": 42, "column": 25}
                },
                "old_text": "hello_str",
                "new_text": "parse_int(hello_str)"
              }
            }
          ],
          "related": [
            {
              "message": "Function add defined here with signature (Int, Int) -> Int",
              "location": {"file": "math.anvil", "line": 10, "column": 1}
            }
          ]
        }
      ],
      "warnings": [],
      "summary": {
        "total_errors": 1,
        "total_warnings": 0,
        "fixable_errors": 1
      }
    }

### Compiler Modes

    # Normal compilation - outputs JSON to stderr, binary/output to stdout
    anvil build main.anvil

    # Check only - no output artifact
    anvil check main.anvil

    # Auto-fix - apply all high-confidence suggestions
    anvil fix main.anvil

    # Format - canonical formatting
    anvil fmt main.anvil

    # REPL with same error format
    anvil repl

### Error Categories

The compiler must distinguish and handle these error types:

1. **Syntax Errors** - malformed source, always fixable with grammar hint
2. **Type Errors** - type mismatch, usually fixable with conversion or signature change  
3. **Exhaustiveness Errors** - missing pattern match cases, fixable by adding cases
4. **Totality Errors** - partial function usage, fixable by handling Result/Option
5. **Effect Errors** - undeclared effects, fixable by adding effect annotation
6. **Scope Errors** - undefined variables, fixable with definition or import
7. **Arity Errors** - wrong number of arguments, fixable with placeholder or removal

Every error category MUST have a suggestion generator.

## Target Runtime

Compile to one of:
- WASM (preferred - portable, sandboxed)
- Native via LLVM
- Transpile to Rust (leverage Rust's guarantees)

Start with an interpreter for bootstrapping, add compilation later.

## Minimal Language Spec

### Keywords (21 total)

    fn          -- function definition
    let         -- immutable binding
    mut         -- mutable binding  
    type        -- type alias
    struct      -- record type
    enum        -- sum type
    match       -- pattern matching
    if          -- conditional
    then        -- conditional continuation
    else        -- conditional alternative
    loop        -- infinite loop
    break       -- exit loop with value
    return      -- early return
    import      -- bring names into scope
    module      -- module definition
    pub         -- public visibility
    true        -- boolean literal
    false       -- boolean literal
    and         -- logical and
    or          -- logical or
    not         -- logical not

### Built-in Types

    Int         -- 64-bit signed integer
    Float       -- 64-bit floating point
    Bool        -- boolean
    String      -- UTF-8 string
    Char        -- Unicode scalar value
    List[T]     -- dynamic array
    Option[T]   -- Some(value) or None
    Result[T,E] -- Ok(value) or Err(error)
    Unit        -- empty type, single value ()
    Never       -- uninhabited type (for diverging functions)

### Syntax Examples

    module Main

    import Std.IO (println, readln)
    import Std.Parse (parse_int)

    -- Function with explicit types
    fn add(x: Int, y: Int) -> Int {
        x + y
    }

    -- Function that can fail
    fn safe_divide(x: Int, y: Int) -> Result[Int, String] {
        if y == 0 then
            Err("division by zero")
        else
            Ok(x / y)
    }

    -- Pattern matching must be exhaustive
    fn describe(opt: Option[Int]) -> String {
        match opt {
            Some(n) => "Got: " + int_to_string(n),
            None => "Nothing"
        }
    }

    -- Main with IO effect
    fn main() -> IO[Unit] {
        let name: String = readln()
        println("Hello, " + name)
    }

## Self-Documenting Architecture

**Critical**: LLMs have limited context. The language must be self-documenting in a way that relevant docs are *always* discoverable from code and errors.

### Principle: Every Error References Its Own Documentation

Every error code (E001, E002, etc.) has a corresponding file:

    docs/errors/E001_type_mismatch.md
    docs/errors/E002_undefined_variable.md
    ...

The error JSON includes the doc path (see schema above). When fixing an error, the LLM can read *just that file* to understand the error deeply.

### Error Doc Format

Each error doc follows a strict template. Key sections:

- Summary: One-line description
- Common Causes: Numbered list
- Fix Strategies: Numbered strategies with code examples
- Examples: ERROR CODE / FIX pairs that match test cases
- Related Errors: Links to related error codes
- See Also: Links to concept docs

### Concept Docs

Higher-level docs that error docs reference:

    docs/concepts/
    ├── types.md              # All types, one page
    ├── functions.md          # Function syntax and semantics
    ├── pattern_matching.md   # Match expressions
    ├── option_result.md      # Handling absence and failure
    ├── effects.md            # Effect system
    └── modules.md            # Module system

Each concept doc is **self-contained** and **under 500 lines**.

### Code-to-Doc Linking

Every compiler module includes a header comment linking to its spec.

### CLAUDE.md - The Entry Point

Create a CLAUDE.md file in the repo root with:

- Quick Navigation sections for common tasks
- Error Code Ranges (E001-E099: Type errors, etc.)
- Key Files listing
- Conventions

## File Structure

    anvil/
    ├── RALPH_PROMPT.md
    ├── CLAUDE.md
    ├── docs/
    │   ├── errors/
    │   ├── concepts/
    │   └── spec/
    ├── src/
    │   ├── lexer/
    │   ├── parser/
    │   ├── typechecker/
    │   ├── errors/
    │   ├── codegen/
    │   └── main.rs
    ├── stdlib/
    ├── tests/
    │   ├── should_pass/
    │   ├── should_fail/
    │   └── error_format/
    └── examples/

## Implementation Language

Use **Rust** for the compiler.

## Success Criteria

### Phase 1: Foundation (iterations 1-100)
- [ ] Lexer produces tokens from source
- [ ] Parser produces AST from tokens
- [ ] AST can be pretty-printed back to valid source
- [ ] Error output is valid JSON matching schema
- [ ] Basic expressions evaluate correctly (interpreter)
- [ ] CLAUDE.md exists and is accurate
- [ ] At least 5 error codes have full documentation

### Phase 2: Type System (iterations 100-300)
- [ ] Type checker validates all constructs
- [ ] Type errors include expected vs actual
- [ ] Type errors include fix suggestions
- [ ] Option and Result types work
- [ ] Pattern match exhaustiveness checking
- [ ] All type errors (E001-E099) have documentation
- [ ] anvil docs --verify passes

### Phase 3: Usability (iterations 300-500)
- [ ] All error categories have suggestion generators
- [ ] anvil fix applies suggestions correctly
- [ ] Standard library basics (IO, String, List)
- [ ] Multiple files/modules work
- [ ] Tests all pass
- [ ] All error codes have documentation with examples
- [ ] Every test links to its corresponding doc
- [ ] Concept docs cover all language features

### Phase 4: Compilation (iterations 500+)
- [ ] WASM output works
- [ ] Compiled programs run correctly
- [ ] Performance is reasonable
- [ ] Doc generation (anvil docs) works

## Completion Signal

Output <promise>ANVIL_PHASE_1_COMPLETE</promise> when Phase 1 is done.
Output <promise>ANVIL_PHASE_2_COMPLETE</promise> when Phase 2 is done.
Output <promise>ANVIL_PHASE_3_COMPLETE</promise> when Phase 3 is done.
Output <promise>ANVIL_COMPLETE</promise> when all phases are done.

## Process Guidelines

1. **Test-Driven**: Write the test for expected behavior first, then implement
2. **Error-First**: When adding a feature, implement the error cases and messages first
3. **Small Commits**: Each iteration should make one focused change
4. **Self-Documenting**: Update specs as implementation reveals better designs
5. **Eat Your Own Dogfood**: Use the error output to guide fixes

## Anti-Patterns to Avoid

- Don't add syntax sugar until core is solid
- Don't implement type inference beyond local let bindings
- Don't add features not in the minimal spec without explicit prompt update
- Don't output prose errors—always JSON
- Don't skip writing tests to move faster
- Don't implement optimizations before correctness

## When Stuck

If after 10 iterations no progress is made on a criterion:
1. Document the blocking issue in BLOCKING.md
2. Simplify the criterion or split it
3. Add more specific tests that demonstrate the requirement
4. Continue to next unblocked criterion

---

**Remember: The goal is a language an LLM can write perfectly because when it makes mistakes, the compiler tells it exactly how to fix them.**
