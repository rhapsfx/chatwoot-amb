---
name: chatwoot-amb-specs
description: Write and maintain RSpec coverage for Chatwoot Apple Messages for Business integrations. Use when editing or reviewing AMB services, payload builders/validators, bot flows, rich link behavior, and log sanitization in `app/services/apple_messages_for_business/**`, `app/models/channel/apple_messages_for_business.rb`, or related integration specs under `spec/services/apple_messages_for_business/**` and `spec/integration/apple_messages_for_business_message_flow_spec.rb`.
---

# Chatwoot AMB Specs

## Quick Start

1. Find the changed AMB code path and its nearest existing spec file.
2. Extend existing AMB specs before creating a new spec file.
3. Add examples for behavior, failure paths, and log/base64 safety when payload data is touched.
4. Run focused specs first, then broaden if needed.
5. Report exactly what was validated and what remains untested.

## Preferred Spec Targets

- Service specs: `spec/services/apple_messages_for_business/*_spec.rb`
- Integration flow: `spec/integration/apple_messages_for_business_message_flow_spec.rb`
- Payload validation and content attributes:
  `spec/validators/apple_messages_for_business/content_attribute_validator_spec.rb`

## Workflow

### 1) Map The Change
- Identify the exact public method/entrypoint modified.
- Map dependencies (service calls, Redis locks, payload validators, network clients, template adapters).
- Confirm if the change can emit large payloads or base64 strings in logs.

### 2) Pick Test Level
- Unit/service spec for deterministic behavior changes.
- Integration spec only when flow across components changed.
- Prefer small focused examples over broad end-to-end setup.

### 3) Write AMB-Safe Assertions
- Verify payload shape and key routing logic (`richLinkData` vs `richLinkDataRef`, request IDs, menu routing, etc.).
- Validate idempotency/locking behavior where present.
- Assert errors/fallbacks for malformed interactive payloads.
- For logging-sensitive paths, assert sanitized output and absence of raw base64 dumps.

### 4) Run Focused Specs
- Run one file:
  `bundle exec rspec spec/services/apple_messages_for_business/<target>_spec.rb`
- Run AMB service suite:
  `bundle exec rspec spec/services/apple_messages_for_business`
- Run message flow when relevant:
  `bundle exec rspec spec/integration/apple_messages_for_business_message_flow_spec.rb`

### 5) Report Risk
- Note behavior covered and uncovered.
- Call out payload-size/logging regressions explicitly.
- If stubs or mocks hide risk (network, Redis, Apple gateway), state it.

## Conventions To Preserve

- Match existing AMB spec style already used in this repo.
- Prefer explicit doubles/stubs over broad global stubs unless existing spec already uses `allow_any_instance_of`.
- Keep examples deterministic; never depend on external network calls.
- If code logs payload-like hashes, sanitize before assertion and avoid embedding huge fixtures.

## References

- Read [amb-spec-patterns.md](./references/amb-spec-patterns.md) for reusable patterns and checks.

### scripts/
Executable code (Python/Bash/etc.) that can be run directly to perform specific operations.

**Examples from other skills:**
- PDF skill: `fill_fillable_fields.py`, `extract_form_field_info.py` - utilities for PDF manipulation
- DOCX skill: `document.py`, `utilities.py` - Python modules for document processing

**Appropriate for:** Python scripts, shell scripts, or any executable code that performs automation, data processing, or specific operations.

**Note:** Scripts may be executed without loading into context, but can still be read by Codex for patching or environment adjustments.

### references/
Documentation and reference material intended to be loaded into context to inform Codex's process and thinking.

**Examples from other skills:**
- Product management: `communication.md`, `context_building.md` - detailed workflow guides
- BigQuery: API reference documentation and query examples
- Finance: Schema documentation, company policies

**Appropriate for:** In-depth documentation, API references, database schemas, comprehensive guides, or any detailed information that Codex should reference while working.

### assets/
Files not intended to be loaded into context, but rather used within the output Codex produces.

**Examples from other skills:**
- Brand styling: PowerPoint template files (.pptx), logo files
- Frontend builder: HTML/React boilerplate project directories
- Typography: Font files (.ttf, .woff2)

**Appropriate for:** Templates, boilerplate code, document templates, images, icons, fonts, or any files meant to be copied or used in the final output.

---

**Not every skill requires all three types of resources.**
