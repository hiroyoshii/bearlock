---
name: keep-design-simple
description: Apply Simple Design, Single Source of Truth, and Subtractive Design when implementing or reviewing changes to code, tests, CI, configuration, migrations, compatibility paths, or fallbacks. Use when a change may add structural elements or leave replaced paths behind; do not expand into unrelated cleanup.
---

# Keep Design Simple

Keep the touched system coherent and as small as the requirement permits.

## Before changing it

Inspect the existing implementation and identify:

- the current owner of the behavior;
- every execution path for it;
- the source of truth for its data, configuration, and test selection;
- elements the proposed change would replace or duplicate.

Prefer changing or replacing the existing owner. Add a parallel path only when the requirement demonstrably needs independent behavior.

## Apply Simple Design

Use these priorities in order:

1. The required behavior works and is verified.
2. The implementation reveals its intent.
3. Knowledge and behavior are not duplicated.
4. The design has the fewest necessary elements.

Do not retain an element merely because it may be useful later.

## Maintain one source of truth

Give each fact or policy one authoritative representation. Other consumers may reference it but must not maintain independent copies.

Pay particular attention to duplicated:

- test-case lists and build commands;
- CI triggers and release paths;
- configuration defaults and product identifiers;
- state derivation and persistence rules;
- compatibility, migration, retry, and fallback decisions.

Reuse is not sufficient when the reused mechanism itself is unnecessary. Remove redundant concepts before extracting shared machinery.

## Design subtractively

For every new file, workflow, abstraction, flag, state, or fallback, first consider whether the change can instead:

- delete an obsolete path;
- replace an existing path;
- merge behavior into its current owner;
- reduce states or branches;
- use an existing verification path.

Temporary diagnostics and one-off validation must not become permanent architecture. Avoid compatibility or fallback behavior without a concrete current requirement.

Apply subtraction only within the requested change and directly affected structure. Do not perform unrelated cleanup.

## Finish the change

Before completion:

- remove paths and artifacts superseded by the change;
- confirm there is one authoritative implementation and verification route;
- search the touched area for duplicated commands, identifiers, conditions, and test lists;
- verify the smallest coherent result, not only the newly added path;
- report any duplication or fallback that remains and its concrete requirement.
