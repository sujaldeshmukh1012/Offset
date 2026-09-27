#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -ne 1 ]; then
    printf 'Usage: %s /absolute/path/to/staging-directory\n' "$0" >&2
    exit 64
fi

staging_root="$1"
if [ ! -d "$staging_root" ]; then
    printf 'Staging directory does not exist: %s\n' "$staging_root" >&2
    exit 66
fi

incentive_source="$repo_root/Data/offset_seed.json"
location_source="$repo_root/Offset/Resources/location_catalog.json"
target_directory="$staging_root/offset-catalogs"

jq -e '.meta.schema_version == "1" and (.programs | length > 0) and (.coverage | length > 0)' \
    "$incentive_source" >/dev/null
jq -e '.schemaVersion == 1 and (.stateZIPRanges | length > 0) and (.utilityProviders | length > 0)' \
    "$location_source" >/dev/null

mkdir -p "$target_directory"
cp "$incentive_source" "$target_directory/offset_seed.json"
cp "$location_source" "$target_directory/location_catalog.json"

printf 'Prepared Supabase Storage catalogs for bucket offset-catalogs:\n'
shasum -a 256 "$target_directory/offset_seed.json" "$target_directory/location_catalog.json"
