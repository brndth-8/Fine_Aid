# Fine Aid — firstAidContent Firestore Seeder

Populates the `firstAidContent` Firestore collection (project `fine-aid-9e0a9`)
from `firstAidContent.json` — 667 chunks extracted and parsed from:

| Source | Chunks | Topic |
|---|---|---|
| First Aid/CPR/AED Participant's Manual | 43 | `animal_bites`, `burns`, `wounds`, `fractures`, etc. (Chapters 6-8 of the manual: Environmental Emergencies, Soft Tissue Injuries, Muscle/Bone/Joint Injuries) |
| WHO — Integrated Approach to Management of Skin-Related NTDs and Common Skin Conditions (CC BY-NC-SA 3.0 IGO) | 93 | leprosy, leishmaniasis, lymphatic filariasis, deep mycoses, scabies, yaws, common fungal/bacterial/viral skin conditions, wound care, patient education |
| Non-Rx OTC Medicines Directory | 531 | `otc_medication`, one chunk per branded product (antacids, analgesics, cold/cough remedies, vitamins, topical antibiotics, etc.) |

Each document has the schema:

```json
{
  "title": "Animal Bites",
  "content": "...full chunk text...",
  "topic": "animal_bites",
  "subtopic": "Chapter 6: Environmental Emergencies",
  "keywords": ["animal", "bite", "bites", "cat", "dog", "rabies", "scratch"],
  "source": "First Aid/CPR/AED Participant's Manual",
  "page": 1
}
```

(`subtopic` is an added field beyond the original spec — it carries chapter/
category context and is safe to ignore if you don't need it.)

## Setup

```bash
npm install
```

Download a service account key for the `fine-aid-9e0a9` Firebase project:
Firebase Console → Project settings → Service accounts → Generate new
private key. Save the downloaded file as `serviceAccountKey.json` in this
folder (it's gitignored — never commit it).

## Run

```bash
node seed.js --dry-run   # validate the data without writing anything
node seed.js             # write all 667 chunks to Firestore
```

The script is idempotent — each chunk has a stable `id` (`chunk_0001`, ...),
so re-running overwrites the same documents rather than duplicating them.
It batches writes in groups of 450 (Firestore's cap is 500 per batch).

## Notes on the OTC medicines source

The Non-Rx meds PDF is a commercial drug-directory-style reference (MIMS
Philippines format) with brand names, manufacturers, and Philippine peso
pricing per entry. It was included as-is per your confirmation. If you ever
want to swap it for a safer, brand-agnostic OTC dataset (generic drug class
guidance only, no brand names/pricing), the parser that produced these
chunks is `extract_nonrx.py` in the sibling `txt/` extraction folder — happy
to write a rewritten version if you change your mind later.
