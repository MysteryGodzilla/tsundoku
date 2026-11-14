# Book lookup sources: Open Library and the alternatives

Researched 2026-11-14, after the Phase 0 spike missed two Australian books on a real phone.
**Product rule today:** Open Library is the only source, with no fallback to Google Books or any
other database. Adding a source changes that rule, so it is the product owner's decision.

## Test: recent Australian books
48 print ISBNs (2015 to 2025) taken from the National Library of Australia's catalogue, from twelve
Australian publishers (Fremantle, UQP, Affirm, Scribe, Allen & Unwin, Hachette, Pan Macmillan,
Penguin Random House Australia, HarperCollins Australia, Hardie Grant, Ultimo and others).

| Source | Found | Covers | Notes |
|---|---|---|---|
| Open Library | **17 of 48 (35%)** | 3 of 48 | Small presses vary: Fremantle 4/4, UQP 3/4, Scribe 0/4, Allen & Unwin 0/4 |
| Inventaire | 0 of 48 | n/a | Works (finds The Night Circus), but has almost no Australian books |
| Google Books | not tested | n/a | Keyless requests get a quota of **0** (HTTP 429): needs a Google Cloud API key |
| Trove (NLA) | not tested | n/a | Needs a free API key. Australia's legal deposit means almost every Australian book is in the national catalogue (all 48 came from it) |

## The options
| Source | Cost | Key | Strengths | Catches |
|---|---|---|---|---|
| **Open Library** (current) | free | none | Open data, covers by ID, work records that link editions (the owned check) | Weak on Australian books and covers |
| **Trove** (National Library of Australia) | free for non-commercial use, including free services | yes, free; keyless requests are refused (HTTP 401, tested), 200 requests/min with one | Near-complete for Australian books (legal deposit) | Commercial use needs permission; mostly no covers; each install or server needs a key, or the key is built into her own copy |
| **Google Books** | free | yes (Google Cloud project; no billing needed) | Large worldwide catalogue, covers, good for retail books | Brief excludes it by name; Google terms; a key in an open-source app must be locked to the app's signing key |
| Inventaire / Wikidata | free, CC0 | none | Fully open | Too thin for ordinary trade books |
| ISBNdb | paid (from about US$15 a month) | yes | Deep ISBN data | Paid: breaks the free principle |
| Hardcover | free | account token | Modern community catalogue | Needs an account per user; app-use terms unclear |
| NLA catalogue search pages | free | none | Same data as Trove | Not an official API; use Trove instead |

## Decision (2026-11-14)
- **Open Library only for now.** Books it doesn't know are typed in.
- **Built for more later:** lookups go through a `BookSource` interface, and each book keeps all of
  its identifiers, so another source can be added without changing the rest (roadmap section 3.5).
- **Trove:** the likely next source. A key has been applied for; approval can take a while.
- **Inventaire:** a possible open backup later. It didn't help with these Australian books.
- **Google Books:** not used. **ISBNdb:** not used (paid).

## Recommendation made before the decision
Keep Open Library first (no key, open, its work records power the owned check), and when it
doesn't know an ISBN, ask **Trove** before falling back to typing it in. That fits an Australian
library best, stays free, and adds no tracking. Covers for those books come from her own photo
(already a product rule), since Trove rarely has them.

Before deciding, test Trove and Google Books against the same 48 books (both need a free key,
which needs Mystery's OK to sign up), and against her two books that weren't found.

## Sources
- [Trove API: what it is](https://trove.nla.gov.au/about/create-something/using-the-api/what-is-the-trove-api) and [terms of use](https://trove.nla.gov.au/about/create-something/using-api/trove-api-terms-use)
- [Google Books API: using the API](https://developers.google.com/books/docs/v1/using)
- [Inventaire entities data](https://wiki.inventaire.io/wiki/Entities_data)
- [Open Library developer API](https://openlibrary.org/developers/api)
