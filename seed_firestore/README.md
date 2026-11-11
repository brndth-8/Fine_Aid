# Fine Aid — firstAidContent Firestore Seeder

Populates the `firstAidContent` Firestore collection (project `fine-aid-9e0a9`)
from `firstAidContent.json` — 157 chunks extracted and parsed from:

| Source | Chunks | Topic |
|---|---|---|
| First Aid/CPR/AED Participant's Manual | 43 | `animal_bites`, `burns`, `wounds`, `fractures`, etc. (Chapters 6-8 of the manual: Environmental Emergencies, Soft Tissue Injuries, Muscle/Bone/Joint Injuries) |
| WHO — Integrated Approach to Management of Skin-Related NTDs and Common Skin Conditions (CC BY-NC-SA 3.0 IGO) | 93 | leprosy, leishmaniasis, lymphatic filariasis, deep mycoses, scabies, yaws, common fungal/bacterial/viral skin conditions, wound care, patient education |
| `OTC products.pdf` (curated, Nov 2026) | 21 | `otc_medication`: 10 dressing/bandage supplies (First Aid/CPR/AED manual, First Aid Pocket Guide, Philippine Red Cross, St. John Ambulance) and 11 MIMS Non-Rx products (paracetamol, cetirizine, ibuprofen, mefenamic acid, chlorhexidine, povidone-iodine). Replaces the older 531-product directory. Peso prices are left out. |

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
node seed.js             # write all 157 chunks to Firestore
node seed.js --prune     # same, and delete older seeded chunks no longer in the file
```

The script is idempotent — each chunk has a stable `id` (`chunk_0001`, ...),
so re-running overwrites the same documents rather than duplicating them.
It batches writes in groups of 450 (Firestore's cap is 500 per batch).

## Notes on the OTC source

The `otc_medication` chunks (ids `chunk_0137` onward) come from the curated
`OTC products.pdf`. Each MIMS entry keeps its original abbreviations
(`childn`, `w/`, `eg`) and its Rx/Non-Rx note (Allermed tablets and Ponser
500 mg are Rx; only the forms the PDF marks Non-Rx are over the counter).
Duplicated entries in the PDF (Hansol, Saniscrub E) are stored once. The
`subtopic` of a MIMS product is a plain category label added for searching;
it is not from the PDF.

The older 531-product directory is replaced: `chunk_0137`-`chunk_0157` are
overwritten by the new chunks and the rest (`chunk_0158`-`chunk_0667`) are
removed from Firestore with `node seed.js --prune`. Run `--prune --dry-run` first to see the count.
