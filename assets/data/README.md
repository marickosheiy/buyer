# Philippine postal-code snapshot

`ph_postal_codes.json` contains 959 four-digit postal routing records extracted
from the public [PHLPost ZIP Code Locator](https://phlpost.gov.ph/zip-code-locator/)
on October 26, 2026. The source and retrieval date are included in the JSON.
The source's nonnumeric Cajidiocan entry was omitted. No postal codes were inferred
from PSGC identifiers or filled in from unverified third-party lists.

This published table is not complete coverage of every municipality, barangay or
postal district. The registration form auto-fills only a unique province/locality
match, normalizing city labels and common Santa/Santo spellings. A missing or
ambiguous match leaves the field empty for manual confirmation. The field remains
editable because postal areas can be more specific than municipality boundaries.
Region/province/city changes clear the old code; stale asynchronous lookup results
are discarded. Lookup is local and needs no additional network request.

To update, retrieve the official table, preserve names and four-digit codes as
strings, validate province/locality combinations and ambiguous entries, update
the source date, and run the registration postal-code tests. The PSGC v2 response
observed during implementation had conflicting zip_code values for several Laguna
municipalities; those values are deliberately not used as a fallback.
