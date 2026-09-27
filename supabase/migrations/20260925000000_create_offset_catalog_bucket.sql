-- Private premium catalog storage for the Offset iOS app.
-- Run with the Supabase CLI or paste into the production project's SQL Editor.
insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'offset-catalogs',
    'offset-catalogs',
    false,
    2000000,
    array['application/json']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- No client policy is created. The premium-catalog Edge Function reads these
-- objects with the service role only after it verifies RevenueCat entitlement.
