#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPPING_FILE="${SCRIPT_DIR}/../rdi-core-mapping.json"

if [[ ! -f "${MAPPING_FILE}" ]]; then
  echo "Missing mapping file: ${MAPPING_FILE}" >&2
  exit 1
fi

raw_ref="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "${raw_ref}" ]]; then
  echo "Server ref is required" >&2
  exit 1
fi

ref="${raw_ref#refs/heads/}"
ref="${ref#refs/tags/}"

line_ref=""

if [[ "${ref}" =~ ^rdi/[0-9]+\.[0-9]+$ ]]; then
  line_ref="${ref}"
elif [[ "${ref}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+\.Final-rdi\.[0-9]+$ ]]; then
  line_ref="rdi/${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
else
  echo "Unsupported server ref '${raw_ref}'. Expected rdi/<major>.<minor> or v<major>.<minor>.<patch>.Final-rdi.<n>" >&2
  exit 1
fi

line_json="$(jq -er --arg line "${line_ref}" '.lines[$line]' "${MAPPING_FILE}")"
core_repo="$(jq -er '.core_repo' <<< "${line_json}")"
core_ref="$(jq -er '.core_ref' <<< "${line_json}")"
upstream_base_tag="$(jq -er '.upstream_base_tag' <<< "${line_json}")"
line_slug="${line_ref//\//-}"

echo "line_ref=${line_ref}"
echo "line_slug=${line_slug}"
echo "core_repo=${core_repo}"
echo "core_ref=${core_ref}"
echo "upstream_base_tag=${upstream_base_tag}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "line_ref=${line_ref}"
    echo "line_slug=${line_slug}"
    echo "core_repo=${core_repo}"
    echo "core_ref=${core_ref}"
    echo "upstream_base_tag=${upstream_base_tag}"
  } >> "${GITHUB_OUTPUT}"
fi
