# Paste-to-parse: parser metrics and regression policy

Parser: `lib/features/orders/domain/paste_parser.dart` (rule-based, on-device, no network).
Corpus: `test/fixtures/paste_corpus.dart` (hand-written cases + templated cases), scored by
`test/domain/paste_parser_test.dart`.

## Current result (125 fixture messages)
| Field | Precision | Recall |
|---|---|---|
| Phone | - | 1.00 |
| Name | 1.00 | 1.00 |
| Address (contains expected area) | 1.00 | 1.00 |
| Product lines (catalog id + qty) | 1.00 | 1.00 |

**Read this honestly:** the corpus is synthetic. I wrote the hand cases and the templates, and tuned
the parser against them, so these numbers prove the parser handles the *shapes I thought of*, not the
real-world rate. Expect lower numbers on real chats (typos, voice-to-text, long Banglish, size/colour
variants, several people's addresses). Replace/extend with real, consented messages from the beta
sellers before quoting accuracy anywhere.

## Enforced targets (test fails below these)
phone recall >= 0.99; name P >= 0.85, R >= 0.80; address P/R >= 0.90; product lines P/R >= 0.85.
Raise the thresholds as the corpus becomes more realistic.

## Known limits (not handled)
- Size/colour tokens after a product ("shirt M 2" keeps qty 1; "M 2" goes to notes).
- Two customers' details in one message; addresses with no place word or keyword.
- Names that are also address words, or names written after the address with no label.
- Bangla-script mentions of products whose catalog name is only English, beyond the small built-in
  synonym table (`_synonyms`): add synonyms, or name the catalog product in both languages.
- Ambiguous catalog matches are flagged (amber) and the seller picks; the parser never guesses silently.

## Regression policy
Every reported mis-parse becomes a new `PasteCase` in `handCases` *before* the fix.

## Exit criteria still to measure
- Median time to create an order from paste vs manual (target 40% faster): the app records
  `paste_parsed` and `paste_to_form` (ms) telemetry events when the user has opted in; compare with
  `order_created` (ms) for manually entered orders.
- Parser never overwrites an existing customer: covered by `test/widget/paste_order_test.dart`
  (an existing customer is selected as saved; the pasted name is shown only as a difference).

## Optional LLM assist
Not implemented. If added later it must be opt-in and off by default, show the exact text that will
be sent, send only the pasted text (never the customer database), and be disclosed in the privacy
policy and Play data-safety form.
