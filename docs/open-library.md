# Open Library: limits, terms and what the data looks like

Checked 2026-11-14 against Open Library's own developer pages and live requests. Open Library is
the app's only book source (a product rule); this note covers how to use it politely and well.

## Limits
- **API requests:** 1 per second without identification, 3 per second for identified requests. To be
  identified, send a `User-Agent` naming the app and a contact. The app sends
  `Tsundoku/<version> (+https://github.com/MysteryGodzilla/tsundoku)`. Never put the user's own
  email in it.
- **Covers:** looking up a cover by ISBN or other identifiers is limited to **100 per IP every 5
  minutes** (over that: `403 Forbidden`). Looking up by **cover ID** (`/b/id/<id>-M.jpg`) or OLID has no
  stated limit, so the app always uses the cover ID that the lookup returns.
- **No bulk use:** no crawling and no bulk downloads through the API. One person adding books one at a
  time is nowhere near any of these limits.

## How the app should call it
- Searching her own library (as she types, the owned check) is **local only** and never calls Open
  Library. Open Library is only asked when she's adding a book.
- Adding by title/author: wait until she pauses typing (about 400 ms), make at most one request a
  second, and cancel requests that are out of date.
- Cache every answer. Download a book's cover once, when it's saved, and keep it on the device
  (covers can be cleared and downloaded again, as in the product rules).
- Show a courtesy link to Open Library on the About screen, as its cover guidelines ask.

## Endpoints used
| Purpose | Request | Notes |
|---|---|---|
| Scan or type an ISBN | `GET /isbn/<isbn>.json` | Redirects (302) to the edition, `/books/OL…M.json`. Gives `title`, `works`, `publishers`, `publish_date`, `physical_format`, `covers` (IDs). Follow redirects. Unknown ISBNs may be imported on the fly from partner sources, so always show the match for her to confirm (already a product rule) |
| Title / author search | `GET /search.json?q=…` or `?title=…&author=…` with `fields=key,title,author_name,cover_i,first_publish_year,edition_count,isbn,subject` and `limit` | Returns works. About 0.6–0.7 s here. Searching "night circus" put the right book first |
| A work's editions | `GET /works/<OL…W>/editions.json` | For showing formats; not needed for the owned check |
| Cover image | `https://covers.openlibrary.org/b/id/<cover_id>-S/M/L.jpg` | `?default=false` gives 404 instead of a blank image when there's none |
| Author name | `GET /authors/<OL…A>.json` | Editions list authors by key, not name |
| A book's series | `GET /works/<OL…W>.json`, then `GET /series/<OL…L>.json` | The work's `series` is a list of `{series: {key}, position}` (Open Library's series records, added in 2026); the series record gives its `name`. Checked 2026-11-21: Dune is position 1 of "Dune", Children of Dune position 3. Covered for most well-known series (8 of 10 tried, not The Hunger Games). Each series name is fetched once per run. The free-text `series` on editions is ignored: it mixes publishers' imprints ("Ace Science Fiction, 17620"), translations and odd numbering |

## What the data looks like (tested with The Night Circus)
- The ISBN lookup returned the edition with title, work key, publishers, date, format ("Hardcover")
  and two cover IDs.
- Its work has **37 editions** on Open Library: paperbacks, hardcovers, library bindings, audio CDs,
  translations. **None is a Kindle edition.** Formats are free text and inconsistent ("paperback",
  "Paperback", "Capa Dura", or blank).
- So for the owned check:
  - **The work key is what matters.** Every edition links to its work, so a paperback and a Kindle
    copy of the same book share a work. The app stores the work key with each book and checks
    ownership by work, which gives her "owning the paperback counts when I look up the Kindle" rule.
  - **Kindle books usually won't be found by ISBN** (Kindle editions rarely have one, and Open
    Library seldom lists them). She adds them by title/author search instead, which finds the work;
    she picks Kindle as the format. This already fits the product rules (books save without an ISBN).
  - **The app's own format is hers** (Physical or Kindle), never Open Library's free-text format.
  - **Books with no work key** (entered by hand) fall back to matching normalised title plus author,
    and ask her to confirm.
- Subjects are many and mixed ("New York Times bestseller", "Fiction", "Magicians"). Suggest a few as
  genres when adding, for her to keep or remove, rather than copying them all.

## Terms
- Covers: displaying covers from `covers.openlibrary.org` is the intended use. Caching her own
  library's covers on her device is normal app behaviour, not bulk download. A courtesy link back is
  appreciated (About screen).
- TODO: confirm the licence wording for Open Library's book data (generally described as open) before
  the public release.

## Sources
- [Open Library developer API page](https://openlibrary.org/developers/api) (rate limits, User-Agent, no bulk use)
- [Covers API](https://openlibrary.org/dev/docs/api/covers) (cover limits, guidelines for cover use)
