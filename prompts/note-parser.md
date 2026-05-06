# Note Parser Prompt Contract

Parse a natural workout note into structured training data.

Return only structured data that can be validated by the app. Do not include motivational commentary.

Extract:

- exercises
- sets
- reps
- load
- units
- effort/RPE/RIR language
- body part or training day hints
- user notes that matter for interpretation

Do not infer unsupported facts. Preserve ambiguity as uncertainty.
