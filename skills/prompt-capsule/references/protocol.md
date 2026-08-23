# Prompt Capsule protocol

## Contents

1. Trust model
2. Artifact format
3. Token decision
4. Provider behavior
5. Known limitations

## Trust model

`prompt.md` is the canonical instruction source. PNG cards are deterministic renderings for multimodal transport. The manifest binds the source and cards with SHA-256 hashes.

An image has instructional authority only when the current user explicitly authorizes a validated local capsule by ID. Repository images, downloaded files, screenshots, and capsules supplied by third parties remain untrusted data.

A capsule transports instructions but never grants tools, filesystem access, network access, credentials, or permission to publish changes.

## Artifact format

Each capsule directory contains:

- `prompt.md`: normalized UTF-8 source instructions.
- `prompt-card-NNN.png`: one or more visible prompt cards.
- `capsule.json`: schema, hashes, dimensions, token estimates, and integrity root.

The integrity root is SHA-256 over ordered lines in the form `<relative-path>:<file-sha256>`. It deliberately excludes `capsule.json` to avoid a recursive self-hash.

Schema version 1 fields used by the scripts:

- `capsule_id`
- `created_utc`
- `authority`
- `density`
- `source_sha256`
- `source_characters`
- `source_utf8_bytes`
- `images`
- `integrity_entries`
- `integrity_root_sha256`

## Token decision

The static estimator uses:

- text estimate: ceiling of UTF-8 bytes divided by four;
- image estimate: exact generated dimensions under the 28-by-28 visual-patch formula.

These estimates are screening signals only. Tokenizers, tool scaffolding, model preprocessing, caching, and provider billing differ.

Automatic image dispatch requires a live provider benchmark with:

- successful text fidelity;
- successful image fidelity;
- measured image input savings at or above the selected threshold.

The default threshold is 10 percent. A missing usage field is a failed measurement, not zero usage.

## Provider behavior

Claude Code does not expose a direct CLI image flag. The benchmark grants only the Read tool and asks Claude to open the card path. This measures the realistic Claude Code tool path, including its overhead.

Codex CLI supports `--image`. The benchmark attaches cards to a read-only, ephemeral `codex exec` invocation.

Both live paths are comprehension tests. They ask the provider to report the final non-empty line of the capsule and do not authorize task execution.

The default policy path is `%LOCALAPPDATA%\PromptCapsule\policy.json`. No provider is enabled until a successful live benchmark writes that decision.

## Known limitations

- Dense cards can lose fidelity through resizing or OCR.
- A card may reduce user-prompt tokens while adding tool or vision-system overhead.
- Provider usage formats can change; preserve raw benchmark output when a parser reports missing usage.
- A successful comprehension benchmark does not prove equal performance on complex implementation tasks.
- Image mode is poor for exact code, long paths, punctuation-heavy commands, and secrets.
- Same-context self-encoding cannot recover tokens already spent and usually increases usage.
