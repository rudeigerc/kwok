#!/usr/bin/env bash
# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"

ROOT_DIR="$(realpath "${DIR}/..")"

function gendoc() {
  local confdir="${ROOT_DIR}/hack/api_docs"

  go run github.com/ahmetb/gen-crd-api-reference-docs \
    -template-dir "${confdir}" \
    -config "${confdir}/config.json" \
    "$@"
}

function check() {
  echo "Update api docs"
  gendoc \
    -api-dir "sigs.k8s.io/kwok/pkg/apis/" \
    -out-file "site/content/en/docs/generated/apis.md"
}

cd "${ROOT_DIR}" && check
