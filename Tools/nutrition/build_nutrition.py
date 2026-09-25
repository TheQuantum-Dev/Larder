#!/usr/bin/env python3
"""Builds Larder/Larder/Recipes/nutrition.json from USDA FoodData Central.

Nutrition per 100 g (energy, protein, carbohydrate, fat) for the ingredients
the recipes use. The values come straight from USDA FoodData Central bulk CSV
downloads (public domain, CC0 1.0): https://fdc.nal.usda.gov/download-datasets

    python3 Tools/nutrition/build_nutrition.py \
        --sr /path/to/FoodData_Central_sr_legacy_food_csv_2018-04 \
        --foundation /path/to/FoodData_Central_foundation_food_csv_2026-04-30 \
        --out Larder/Larder/Recipes/nutrition.json

Each entry is keyed by a nutrition key. A recipe line uses its ingredient id
unless it names a variant (for example "rice-cooked") in its "nutri" field.
"""
import argparse
import csv
import json
import re
import sys

SR, FOUNDATION = "sr", "foundation"

# nutrition key -> (dataset, FoodData Central id)
SOURCES = {
    # produce
    "apple": (SR, 171688), "avocado": (SR, 171706), "banana": (SR, 173944),
    "bell-pepper": (SR, 170108), "blueberry": (SR, 171711), "broccoli": (SR, 170379),
    "cabbage": (SR, 169975), "carrot": (SR, 170393), "celery": (SR, 169988),
    "cherry": (SR, 171719), "corn": (SR, 169216), "cucumber": (SR, 168409),
    "frozen-veg": (SR, 170425), "garlic": (SR, 169230), "ginger": (SR, 169231),
    "grape": (SR, 174683), "green-bean": (SR, 169961), "herbs": (SR, 170416),
    "jalapeno": (SR, 168576), "kale": (SR, 168421), "lemon": (SR, 167747),
    "lettuce": (SR, 169247), "lime": (SR, 168155), "mango": (SR, 169910),
    "mushroom": (SR, 169251), "onion": (SR, 170000), "orange": (SR, 169097),
    "peach": (SR, 169928), "pear": (SR, 169118), "peas": (SR, 170016),
    "pineapple": (SR, 169124), "potato": (SR, 170027), "spinach": (SR, 168462),
    "strawberry": (SR, 167762), "sweet-potato": (SR, 168482), "tomato": (SR, 170457),
    "watermelon": (SR, 167765), "zucchini": (SR, 169291),
    # dairy and eggs
    "butter": (SR, 173410), "cheese": (SR, 173414), "egg": (SR, 171287),
    "egg-white": (SR, 172183), "greek-yogurt": (SR, 170903), "milk": (SR, 171267),
    "sour-cream": (SR, 171257), "yogurt": (SR, 170886),
    # protein
    "bacon": (SR, 167914), "beans": (SR, 175243), "beef": (SR, 174030),
    "canned-tuna": (SR, 173709), "chicken": (SR, 171077), "chicken-cooked": (SR, 171477),
    "chickpeas": (SR, 173801), "cod": (SR, 171955), "fish": (SR, 175176),
    "ham": (SR, 173864), "lentils": (SR, 172420), "lentils-cooked": (SR, 172421),
    "nuts": (SR, 170567), "peanut-butter": (SR, 174266), "pork": (SR, 167818),
    "salmon": (SR, 175167), "sausage": (SR, 171631), "shrimp": (SR, 175179),
    "tofu": (SR, 172475), "turkey": (SR, 172850),
    # grains
    "bagel": (SR, 174899), "bread": (SR, 174924), "cereal": (SR, 174648),
    "crackers": (SR, 174982), "flour": (SR, 168894), "oats": (SR, 173904),
    "pasta": (SR, 169736), "pasta-cooked": (SR, 169737), "quinoa": (SR, 168874),
    "ramen": (SR, 171177), "rice": (SR, 168877), "rice-cooked": (SR, 168878),
    "tortilla": (SR, 167535),
    # pantry
    "black-pepper": (SR, 170931), "broth": (SR, 174536), "cooking-oil": (SR, 172370),
    "dressing": (SR, 173592), "honey": (SR, 169640), "hummus": (SR, 174289),
    "jam": (SR, 169641), "ketchup": (SR, 168556), "mayo": (SR, 171009),
    "mustard": (SR, 172234), "olive-oil": (SR, 171413), "olives": (SR, 169094),
    "pickles": (SR, 168558), "salsa": (SR, 174524), "salt": (SR, 173468),
    "soy-sauce": (SR, 174277), "sugar": (SR, 169655), "tomato-sauce": (SR, 170054),
    "vinegar": (SR, 172237),
}

# Carbohydrate "by difference" counts fibre, which carries little energy, so the
# energy check skips low-calorie foods and the spice below.
HIGH_FIBRE = {"black-pepper"}

# Energy is stored as nutrient 1008, or as an Atwater factor on newer records.
ENERGY = ("1008", "2048", "2047")
NUTRIENTS = {"1003": "protein", "1004": "fat", "1005": "carbs"}
LICENSE = ("USDA FoodData Central: SR Legacy (April 2018) and Foundation Foods "
           "(April 2026). Public domain, CC0 1.0. https://fdc.nal.usda.gov")


def read_dataset(folder, wanted):
    foods, values = {}, {}
    with open(f"{folder}/food.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if int(row["fdc_id"]) in wanted:
                foods[int(row["fdc_id"])] = row["description"]
    with open(f"{folder}/food_nutrient.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            fdc = int(row["fdc_id"])
            if fdc not in wanted or row["amount"] == "":
                continue
            nid = row["nutrient_id"]
            if nid in NUTRIENTS:
                values.setdefault(fdc, {})[NUTRIENTS[nid]] = float(row["amount"])
            elif nid in ENERGY:
                energy = values.setdefault(fdc, {}).setdefault("energy", {})
                energy[nid] = float(row["amount"])
    return foods, values


def clean(description):
    return re.sub(r"\s*\(Includes foods for USDA's Food Distribution Program\)", "", description).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sr", required=True)
    parser.add_argument("--foundation")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    folders = {SR: args.sr, FOUNDATION: args.foundation}

    entries, problems = {}, []
    loaded = {}
    for dataset in (SR, FOUNDATION):
        wanted = {fdc for ds, fdc in SOURCES.values() if ds == dataset}
        if wanted:
            if not folders[dataset]:
                sys.exit(f"--{dataset} is required")
            loaded[dataset] = read_dataset(folders[dataset], wanted)

    for key, (dataset, fdc) in sorted(SOURCES.items()):
        foods, values = loaded[dataset]
        if fdc not in foods or fdc not in values:
            problems.append(f"{key}: FoodData Central id {fdc} not found")
            continue
        v = values[fdc]
        energy = next((v["energy"][n] for n in ENERGY if n in v.get("energy", {})), None)
        if energy is None or not {"protein", "fat", "carbs"} <= v.keys():
            problems.append(f"{key}: missing macros for {fdc}")
            continue
        kcal, protein, carbs, fat = round(energy, 1), round(v["protein"], 1), round(v["carbs"], 1), round(v["fat"], 1)
        atwater = 4 * protein + 4 * carbs + 9 * fat
        if kcal > 40 and key not in HIGH_FIBRE and abs(atwater - kcal) / kcal > 0.25:
            problems.append(f"{key}: energy {kcal} vs macros {atwater:.0f} kcal (check the source food)")
        entries[key] = {"fdc": fdc, "food": clean(foods[fdc]), "kcal": kcal,
                        "protein": protein, "carbs": carbs, "fat": fat}

    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)

    lines = ["{", f'  "source": {json.dumps(LICENSE)},', '  "per": "100 g",', '  "foods": {']
    items = sorted(entries.items())
    for i, (key, entry) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        lines.append(f"    {json.dumps(key)}: {json.dumps(entry, ensure_ascii=False)}{comma}")
    lines += ["  }", "}", ""]
    with open(args.out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote {len(entries)} foods to {args.out}")


if __name__ == "__main__":
    main()
