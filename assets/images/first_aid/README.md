# First Aid step images

One file per kind of step, named exactly (the app picks the picture from the
step's wording — see lib/data/first_aid_step_images.dart):

| File | Shown for a step about |
|---|---|
| `wash_hands.png` | washing / cleaning hands, wearing gloves |
| `rinse_water.png` | rinsing or flushing with clean running water |
| `pat_dry.png` | patting the area dry |
| `apply_pressure.png` | pressing gently to stop bleeding |
| `apply_ointment.png` | ointment / cream |
| `apply_antiseptic.png` | antiseptic / disinfectant |
| `apply_dressing.png` | covering with a dressing or bandage |
| `change_dressing.png` | changing the dressing |
| `cool_burn.png` | cooling a burn under running water |
| `cold_compress.png` | a wrapped cold compress |
| `elevate.png` | raising the injured area |
| `rest.png` | resting the injured area |
| `watch_infection.png` | watching for signs of infection |
| `monitor_the_area.png` | monitoring / checking the area |
| `avoid_touching.png` | "do not touch / pick / scratch / pop" |
| `avoid_harsh_product.png` | "do not use alcohol, peroxide, toothpaste, butter…" |
| `call_emergency.png` | emergency / go to the nearest hospital |
| `prepare_clean_warm_water_and_a_soft_towel_1.png` | "Prepare clean warm water and a soft towel" |
| `wash_the_affected_are_and_remove_surface_debris_1.png` | "Wash the affected area and remove surface debris" |
| `protect_the_face_from_direct_sunlight_1.png` | "Protect the face from direct sunlight" |
| `consult_a_doctor_for_formal_evaluation_1.png` | "Consult a doctor for formal evaluation" |
| `Apply_mild_fragrance_free_moisturizer_1.png` | "Apply mild, fragrance-free moisturizer" |
| `consult_a_doctor_if_not_better_1.png` | "Consult a doctor ... if the rash does not get better" |
| `gather_gauze_or_cloth_1.png` | "Get clean running water, clean gauze (or a clean cloth ...)" |
| `keep_track_of_changes_1.png` | "Keep track of when the rash started ..." |
| `air_dry_do_not_rub_1.png` | "let the skin air-dry. Do not rub it with a towel" |
| `check_what_you_see_1.png` | steps that say "what you see" / inspect / examine |
| `keep_area_dry_1.png` | "keep the area dry" |
| `cool_damp_cloth_1.png` | "cool, damp cloth" / cool compress |
| `sterile_gauze_cover_1.png` | "sterile gauze" / gauze pad |
| `gauze_or_clean_towel_1.png` | "gauze or a clean towel" |
| `warning_signs_to_watch_1.png` | fever, swelling, spreading, getting worse |
| `blisters_seek_care_1.png` | steps about blisters |

(The last five are named after their files, including the "are" typo in the
wash one: the key in `first_aid_step_images.dart` must match the file name
exactly.)

Tip: the pictures are shown at about 52-76 px. Files this size (1+ MB each)
make the app bigger than it needs to be; 256x256 px is plenty.
