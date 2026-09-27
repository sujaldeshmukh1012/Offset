-- Apply this after the earlier public-bucket migration if it has already run.
-- Objects stay in place, but public URLs and all anon/authenticated Storage API
-- access are denied. Edge Functions using the service role bypass RLS.
update storage.buckets
set public = false
where id = 'offset-catalogs';

drop policy if exists "Offset catalogs are server only" on storage.objects;

create policy "Offset catalogs are server only"
on storage.objects
as restrictive
for all
to anon, authenticated
using (bucket_id <> 'offset-catalogs')
with check (bucket_id <> 'offset-catalogs');
