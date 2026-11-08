# Inline visual contracts

!!! note "Candidate contract — unreleased"

    This reference accompanies [Inline visuals](inline-visuals.md). It does not
    announce a released package or a compatible current manifest combination.

## Configuration schema

The umbrella repository owns the three canonical v1 JSON schemas under
`contracts/`. Candidate orchestrator and UI wheels package
the same bytes; do not maintain another schema or parser in a customer adapter.

| Schema | SHA-256 |
| --- | --- |
| `agent-presentation-settings-v1.schema.json` | `98295024fbe702890f2a69faeb086e6f3e526b73c05257f580914363d0225d82` |
| `presentation-selection-v1.schema.json` | `48f340384553170cfbc87a10ecc1d3c318078541a271a91e97f472dc332e0a04` |
| `turn-presentation-v1.schema.json` | `cdd7543e522417affac96fd90cc602a4b564ead495ae7b02db53d8e17624f07d` |

The ordinary `json_object` setting is `AGENT_PRESENTATION_SETTINGS`, published
as compact JSON with label `agent-lz` and content type `text/plain`. Its shape is:

```json
{
  "schemaVersion": 1,
  "agents": {
    "agent-lz-conversation": {
      "enabled": true,
      "guidance": "Prefer monthly revenue tables. Preserve source units."
    }
  }
}
```

Use the [runbook's declaration](inline-visuals.md#step-1-enable-one-agent) in
`main.parameters.json`; the declaration's `value` is a JSON string, not an
additional `type` field. Empty `agents`, absent agent or `enabled: false` is off.

## Use the typed-source samples

In the coordinated umbrella feature checkout,
`contracts/examples/inline-presentation/README.md` describes `source-fixture.json`,
three valid/invalid fixture pairs and `text_only_adapter.py`. These are
candidate source artifacts, not links to an already published release.

The synthetic source preserves March revenue as the decimal string **9.750**
with unit **USD**, growth **-2.750**, and indicator **down** linked to the
`revenue-trend` rule and source growth field. Numeric values, units, result IDs,
row IDs and rule bindings come from authorized typed tool results, not model
narration or numbers parsed from prose. Bar, grouped-bar and line are the
supported product chart kinds; schema capacity alone does not enable another kind.

## Integrate a text-only client

1. Apply the client's **existing owner-admission check** to the native result.
   Do not flatten arbitrary JSON or accept a browser-supplied permission flag.
2. Pass the admitted native result to the canonical UI reader shown below.
3. Send the returned text through the client's existing safe text sink.

```python
from gpt_rag_ui.services.native_presentation import text_projection

# native_result was admitted by the client's existing ownership/auth gate.
readable_text = text_projection(native_result)
# Deliver readable_text through the client's existing safe text sink.
```

The umbrella adapter makes that caller precondition explicit with
`render_text(native_result, owner_admitted=...)`. This argument is not
authentication and must never be accepted as a browser-supplied permission.

Ordinary legacy narration remains text. Unknown block kinds are inert.
Unsupported future schema versions project stable markdown only, never future
props or raw-envelope dumps. Do not execute HTML, scripts, future blocks or
component payloads from the envelope. Suggestions and row actions send ordinary
new user messages through existing authorization; they do not create a second
continuation protocol.

## Validate the customer adapter

Use the umbrella's existing local command with the matched candidate UI source
on `PYTHONPATH`:

```powershell
python -m pytest -q tests/test_text_only_adapter.py tests/test_presentation_contracts.py
```

Keep matched readers when disabling new visual generation. These local reader
and schema checks do not certify another channel's deployed behavior.
