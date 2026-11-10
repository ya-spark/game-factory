# Publishing content packs (issue 1D)

Learning content is sold with **real money**, never coins. Every extra pack is its own Play
one-time product (non-consumable); Full Unlock is one product per app. Products are generated from
the pack manifests and `content/catalogue.json`, never typed by hand. The packs live in the private
`ya-spark/game-content` repo; this page describes the tools that repo's workflows call.

## Publish a pack in five steps

1. **Write the pack.** Author the CSV, then `dart run tool/content_cli.dart from-csv <pack.csv> --out packs`.
   In the `#meta` rows (or the JSON) set `product_id` (rule below) and `tier` (a tier id, never a price).
   Leave `status` out: a new extra pack is `draft`.
2. **Check it.** `dart run tool/content_cli.dart products --packs packs --json-out products.json --csv-out products.csv`
   stops on a bad id, an unknown tier, a duplicate or a retired id, and prints nothing wrong-looking.
3. **Create the product in Play** (the `sync-products` workflow reads `products.json`; fallback: import
   `products.csv` in Play Console, One-time products, Import). Check the price in the Console.
4. **Mark it live.** Only now set `"status": "live"` in the manifest (the pack stays hidden in the app until then).
5. **Publish.** `dart run tool/content_cli.dart publish --app <app_id> --packs packs --out site --version N`
   validates, builds `index.json`, signs when a key is set, and lists the files to upload (a dry run: the
   content repo's workflow does the upload). Raise `--version` every time: the app ignores a lower one.

Order matters: **the product exists in Play first, then the pack is `live`.** A `live` pack whose product is
missing shows no price and cannot be bought.

## Product ids

`pack_<subject>_<year>_<slug>`: lower case letters, digits and underscores; `<year>` is `0` (Foundation)
to `12` with no leading zero; at most 40 characters (Play's limit). `<subject>` and `<year>` must match the
pack, so `pack_maths_3_times_tables` is a Year 3 maths pack. Year bundles are `bundle_<year>_<slug>`
(for example `bundle_3_all`).

**Ids are permanent.** Play never lets a deleted product id be created again. Never rename a product id
and never reuse one. When a pack is retired, add its id to `retired_ids` in the catalogue; the tool then
refuses it forever.

## Price tiers and bundles

`content/catalogue.json` holds the currency, region, the tiers and the bundles:

```json
{
  "currency": "AUD", "region": "AU",
  "tiers": { "t1": "0.99", "t2": "1.99", "t3": "2.99", "t4": "4.99", "t5": "7.99", "t6": "12.99" },
  "bundles": [
    { "product_id": "bundle_3_all", "year": 3, "tier": "t5", "title": "Year 3 bundle",
      "description": "Every Year 3 pack.", "status": "draft" }
  ],
  "retired_ids": []
}
```

The six prices are **placeholders** until the owner sets the real price points. Changing a tier price
changes the price of every pack on that tier the next time products are synced. A pack names only its
`tier`. A bundle unlocks every extra pack of its `year` (and of its optional `subject`), including packs
added later: the index lists them and the app treats the bundle as owning each. Bundles follow the same
rule: Play product first, then `"status": "live"`.

## `status` in the index

Each index entry is `draft` or `live` (an index without it counts as `live`). The app hides a `draft` pack
(not listed, not played, never offered for sale) and shows a `live` pack as buyable. A bundle has a status too.

## What the app does

- **Discovery.** The app asks Play about the product ids named in the index at run time (live packs and
  live bundles), so a new pack needs no app update.
- **Ownership.** A pack is owned through its own product or a bundle that lists it. Ownership is shared by
  every child on the device.
- **Restore.** "Restore purchases" first registers the products named in the current index, then asks Play
  to restore. An owned product that is not in the index has no effect; a restored bundle opens each pack it lists.

## Signing

Signing is optional until the owner adds a key. `publish --sign auto` (default) signs when
`CONTENT_SIGNING_KEY_FILE` names a key file and says `NOT SIGNED` otherwise; `--sign no` never signs;
`--sign yes` fails without a key. The matching public key goes into `app.config.yaml`
(`content.signing_public_key`); until then the apps accept an unsigned index (see `docs/CONTENT_FORMAT.md`).

## Play API notes

- Products are created with the Play **one-time products API** (`monetization.onetimeproducts`). The service
  account needs "Manage store presence", and the owner must add each app to the account's permissions once
  the app exists in Play Console.
- The app must already exist in Play Console, and a first build **with the billing permission** may have to
  be uploaded before any in-app product can be created.
- Fallback with no API: import `products.csv` (same columns as `docs/play-import/one_time_products_sample.csv`,
  one row for the listing and one for the purchase option per product; non-consumable, quantity off).
