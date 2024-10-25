#!/usr/bin/env bash

# Copyright 2019 The Kubernetes Authors.
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

readonly VC_GO_PACKAGE=sigs.k8s.io/cluster-api-provider-nested/virtualcluster
readonly VC_ALL_TARGETS=(
  cmd/manager
  cmd/syncer
  cmd/vn-agent
  cmd/kubectl-vc
)
readonly VC_ALL_BINARIES=("${VC_ALL_TARGETS[@]##*/}")

# Define supported OS and architecture combinations
#SUPPORTED_PLATFORMS=("linux/amd64" "linux/arm64" "darwin/amd64" "darwin/arm64")
SUPPORTED_PLATFORMS=("linux/amd64" "linux/arm64")

# binaries_from_targets function
binaries_from_targets() {
  local target
  for target; do
    if [[ "${target}" =~ ^([[:alnum:]]+\.)+[[:alnum:]]+/ ]]; then
      echo "${target}"
    else
      echo "${VC_GO_PACKAGE}/${target}"
    fi
  done
}

# version function
version() {
  GIT_COMMIT=$(git rev-parse HEAD)
  BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  GIT_VERSION="v1.0.0"
  VERSION_PKG=sigs.k8s.io/cluster-api-provider-nested/virtualcluster/pkg/version
  echo "-X ${VERSION_PKG}.gitVersion=${GIT_VERSION} -X ${VERSION_PKG}.gitCommit=${GIT_COMMIT} -X ${VERSION_PKG}.buildDate=${BUILD_DATE}"
}

# build_binaries function with multi-arch support
build_binaries() {
  local goflags goldflags gcflags
  goldflags="${GOLDFLAGS:-} -s -w $(version)"
  gcflags="${GOGCFLAGS:-}"
  goflags=${GOFLAGS:-}

  local -a targets=()
  local arg

  for arg; do
    if [[ "${arg}" == -* ]]; then
      goflags+=("${arg}")
    else
      targets+=("${arg}")
    fi
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    targets=("${VC_ALL_TARGETS[@]}")
  fi

  local -a binaries
  while IFS="" read -r binary; do binaries+=("$binary"); done < <(binaries_from_targets "${targets[@]}")

  mkdir -p "${VC_BIN_DIR}"
  cd "${VC_BIN_DIR}"
  for platform in "${SUPPORTED_PLATFORMS[@]}"; do
    OS="${platform%/*}"
    ARCH="${platform#*/}"

    for binary in "${binaries[@]}"; do
      BIN_OUTPUT="$(basename "${binary}")-${OS}-${ARCH}"
      echo "Building ${binary} for ${OS}/${ARCH} -> ${BIN_OUTPUT}"
      GOOS=${OS} GOARCH=${ARCH} go build -o "${BIN_OUTPUT}" -ldflags "${goldflags}" -gcflags "${gcflags}" ${goflags} "${binary}"
    done
  done
}

# Call build_binaries function
build_binaries "$@"
