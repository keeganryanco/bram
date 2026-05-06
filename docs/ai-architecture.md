# Bram AI Architecture

## Role

AI is an invisible interpretation layer. Bram should not feel like an AI chat product.

## Output Shapes

AI outputs must be one of:

- structured workout summary
- one-line suggestion
- weekly plain-language insight
- progression recommendation
- recovery adjustment
- exercise-history explanation

No generic coaching essays.

## Privacy Rules

- Use pseudonymous user/session IDs in model calls.
- Do not send name or email to AI providers.
- Minimize note context to the task.
- Store raw notes separately from identity metadata where practical.
- Keep prompts in `prompts/` and update them when behavior changes.

## Model Routing

- Note parsing: cheap fast model.
- Exercise normalization: cheap model plus deterministic mapping.
- Inline suggestion: cheap fast model.
- Weekly review: stronger model.
- Explicit complex user request: stronger model only when paid/eligible.
