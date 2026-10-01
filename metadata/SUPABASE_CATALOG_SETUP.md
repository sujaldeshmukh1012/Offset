# Secure Supabase Premium Catalog Setup

Offset stores its complete incentive catalog in a private Supabase Storage
bucket. The iOS app does not contain that premium catalog and cannot read the
bucket directly. It creates a random anonymous Supabase identity, uses the same
UUID as its RevenueCat App User ID, and calls the `premium-catalog` Edge
Function. The function returns the catalogs only when RevenueCat reports an
active `offset_pro` entitlement.

## 1. Lock the Storage bucket

Run both migrations in the production project's SQL Editor, in filename order:

1. `supabase/migrations/20260925000000_create_offset_catalog_bucket.sql`
2. `supabase/migrations/20260925010000_lock_premium_catalog.sql`

The second migration is required if the bucket was initially created as public.
It preserves uploaded objects while disabling public URLs and direct access for
both `anon` and `authenticated` roles. Only the server-side service role can
read the objects.

Prepare and upload the complete catalogs through the Supabase dashboard:

```bash
mkdir -p /tmp/offset-supabase-upload
./scripts/prepare_supabase_catalog.sh /tmp/offset-supabase-upload
```

Upload these files at the root of the private `offset-catalogs` bucket:

- `/tmp/offset-supabase-upload/offset-catalogs/offset_seed.json`
- `/tmp/offset-supabase-upload/offset-catalogs/location_catalog.json`

Use cache control `300`. Publishing later releases uses **Replace**, not a new
public object or bucket.

## 2. Enable anonymous authentication

In **Authentication → Providers → Anonymous Sign-Ins**, enable anonymous
sign-ins. Offset uses this only to obtain a signed, installation-scoped JWT; it
does not request an email, password, name, or other account information.

Keep automatic linking disabled. Consider Supabase's CAPTCHA and rate-limiting
controls before scaling anonymous sign-ins. Anonymous authentication alone does
not grant catalog access—the Edge Function also verifies RevenueCat.

## 3. Deploy the entitlement gate

Install and authenticate the Supabase CLI, then run:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set \
  REVENUECAT_SECRET_API_KEY=sk_your_revenuecat_secret_api_key \
  REVENUECAT_ENTITLEMENT_ID=offset_pro
supabase functions deploy premium-catalog
```

Use a RevenueCat **secret** API key that can read subscribers. It belongs only
in Supabase Edge Function secrets—never in the repository, the iOS app, an
xcconfig file, or App Store Connect. Supabase supplies `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` to the function automatically.

The function validates the caller's Supabase JWT, uses its user UUID as the
RevenueCat App User ID, checks `offset_pro`, and returns the two private objects
inline with `Cache-Control: private, no-store`. It never returns a reusable
Storage URL.

## 4. Configure the iOS app

From **Project Settings → API**, copy the project URL and publishable key. These
identify the backend and are designed to be embedded in an app; they do not
bypass Row Level Security.

Add them to ignored `Offset/Configuration/Secrets.xcconfig`. xcconfig requires
the extra `$()` between URL slashes:

```xcconfig
SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_your_key
```

Do not add the service-role key or RevenueCat secret key.

## 5. Acceptance tests

First confirm direct access is closed. This request must not return either
catalog:

```bash
curl --fail \
  "https://YOUR_PROJECT_REF.supabase.co/storage/v1/object/public/offset-catalogs/offset_seed.json"
```

Then test on a physical device using the `Offset-Sandbox` scheme:

1. Launch with a fresh install and confirm no premium catalog is loaded.
2. Purchase or restore Premium. Confirm RevenueCat's App User ID is the same
   UUID as the anonymous Supabase user and entitlement `offset_pro` is active.
3. In **Settings → Rebate data**, tap **Check for updates**. Verify the catalog
   loads and calculations become available without relaunching.
4. Expire the sandbox subscription and foreground the app. Confirm protected
   catalog files are removed and premium calculations disappear.
5. Call the Edge Function without a JWT and with a nonpremium anonymous JWT;
   expect HTTP 401 and 403 respectively.
6. Run `./scripts/release_preflight.sh` and inspect the release bundle to confirm
   its `offset_seed.json` contains zero programs and `Data/offset_seed.json` is
   absent.

## Security boundary

This design prevents unauthenticated and nonpaying clients from downloading the
catalog. A paying subscriber necessarily receives data needed for on-device
calculations and can inspect their own device traffic or storage. If individual
catalog records must never reach subscribers, calculations must move into the
Edge Function and return only result projections.

`Data/offset_seed.json` is the private authoring source used for uploads and the
Debug-only UI-test fixture. Keep this repository private, or move that file to a
separate private data repository before publishing source code. Deploying the
public support site must publish `docs/` only.
