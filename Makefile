# Copyright 2022 The Kubernetes Authors.
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

GO_CMD ?= go

DRY_RUN ?=
PUSH ?=

BUCKET ?=

GH_RELEASE ?=

VERSION ?= $(shell ./hack/get-version.sh)

BASE_REF ?= $(shell git rev-parse --abbrev-ref HEAD)

EXTRA_TAGS ?=

SUPPORTED_RELEASES ?= $(shell cat ./supported_releases.txt)

BINARY ?= kwok kwokctl

IMAGE_PREFIX ?=

BINARY_PREFIX ?=
BINARY_NAME ?=

STAGING ?= false

GOOS ?= $(shell go env GOOS)

GOARCH ?= $(shell go env GOARCH)

ifeq ($(STAGING),true)
STAGING_IMAGE_PREFIX ?= $(IMAGE_PREFIX)
STAGING_PREFIX ?= $(shell ./hack/get-staging.sh)
else
STAGING_IMAGE_PREFIX = $(IMAGE_PREFIX)
STAGING_PREFIX =
endif

ifeq ($(STAGING_IMAGE_PREFIX),)
KWOK_IMAGE ?= kwok
CLUSTER_IMAGE ?= cluster
else
KWOK_IMAGE ?= $(STAGING_IMAGE_PREFIX)/kwok
CLUSTER_IMAGE ?= $(STAGING_IMAGE_PREFIX)/cluster
endif

PLATFORM ?= $(GOOS)/$(GOARCH)

IMAGE_PLATFORMS ?= linux/amd64 linux/arm64

BINARY_PLATFORMS ?= linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64

BUILDER ?= docker
DOCKER_CLI_EXPERIMENTAL ?= enabled

.PHONY: default
default: help

vendor:
	@$(GO_CMD) mod vendor

## unit-test: Run unit tests
.PHONY: unit-test
unit-test: vendor
	@$(GO_CMD) test ./pkg/...

## verify: Verify code
.PHONY: verify
verify:
	@./hack/verify-all.sh

## update: Update all the generated
.PHONY: update
update:
	@./hack/update-all.sh

## build: Build binary
.PHONY: build
build: vendor
	@./hack/releases.sh \
		$(addprefix --bin=, $(BINARY)) \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--platform=${PLATFORM} \
		--bucket=${BUCKET} \
		--gh-release=${GH_RELEASE} \
		--image-prefix=${IMAGE_PREFIX} \
		--binary-prefix=${BINARY_PREFIX} \
		--binary-name=${BINARY_NAME} \
		--version=${VERSION} \
		--kube-version=v$(shell echo $(SUPPORTED_RELEASES) | tr ' ' '\n' | head -n 1 ) \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--push=${PUSH}

## build-image: Build binary and image
.PHONY: build-image
build-image:
ifeq ($(GOOS),linux)
	@make BINARY=kwok build && \
		make image
else ifeq ($(GOOS),darwin)
	@make BINARY=kwok BINARY_PLATFORMS=linux/$(GOARCH) cross-build && \
		make IMAGE_PLATFORMS=linux/$(GOARCH) cross-image
else
	@echo "Unsupported OS: $(GOOS)"
endif

## build-cluster-image: Build cluster image
.PHONY: build-cluster-image
build-cluster-image:
ifeq ($(GOOS),linux)
	@make build image cluster-image
else ifeq ($(GOOS),darwin)
	@make BINARY=kwok BINARY_PLATFORMS=linux/$(GOARCH) cross-build && \
		make IMAGE_PLATFORMS=linux/$(GOARCH) cross-image cross-cluster-image
else
	@echo "Unsupported OS: $(GOOS)"
endif

## cross-build: Build kwok and kwokctl for all supported platforms
.PHONY: cross-build
cross-build: vendor
	@./hack/releases.sh \
		$(addprefix --bin=, $(BINARY)) \
		$(addprefix --platform=, $(BINARY_PLATFORMS)) \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--bucket=${BUCKET} \
		--gh-release=${GH_RELEASE} \
		--image-prefix=${IMAGE_PREFIX} \
		--binary-prefix=${BINARY_PREFIX} \
		--binary-name=${BINARY_NAME} \
		--version=${VERSION} \
		--kube-version=v$(shell echo $(SUPPORTED_RELEASES) | tr ' ' '\n' | head -n 1 ) \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--push=${PUSH}

## image: Build kwok image
.PHONY: image
image:
	@./images/kwok/build.sh \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--image=${KWOK_IMAGE} \
		--version=${VERSION} \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--builder=${BUILDER} \
		--push=${PUSH}

## cross-image: Build kwok images for all supported platforms
.PHONY: cross-image
cross-image:
	@./images/kwok/build.sh \
		$(addprefix --platform=, $(IMAGE_PLATFORMS))  \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--image=${KWOK_IMAGE} \
		--version=${VERSION} \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--builder=${BUILDER} \
		--push=${PUSH}

## cluster-image: Build cluster image
.PHONY: cluster-image
cluster-image:
	@./images/cluster/build.sh \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--kube-version=v$(shell echo $(SUPPORTED_RELEASES) | tr ' ' '\n' | head -n 1 ) \
		--image=${CLUSTER_IMAGE} \
		--version=${VERSION} \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--builder=${BUILDER} \
		--push=${PUSH}

## cross-cluster-image: Build cluster images for all supported platforms and all supported Kubernetes versions.
.PHONY: cross-cluster-image
cross-cluster-image:
	@./images/cluster/build.sh \
		$(addprefix --platform=, $(IMAGE_PLATFORMS)) \
		$(addprefix --kube-version=v, $(shell echo $(SUPPORTED_RELEASES) | tr ' ' '\n' | head -n 6 )) \
		$(addprefix --extra-tag=, $(EXTRA_TAGS)) \
		--image=${CLUSTER_IMAGE} \
		--version=${VERSION} \
		--staging-prefix=${STAGING_PREFIX} \
		--dry-run=${DRY_RUN} \
		--builder=${BUILDER} \
		--push=${PUSH}

## integration-tests: Run integration tests
.PHONY: integration-test
integration-test:
	@echo "Not implemented yet"

## e2e-test: Run e2e tests
.PHONY: e2e-test
e2e-test:
	@./hack/requirements.sh kubectl buildx kind
	@./hack/e2e-test.sh --skip=nerdctl --skip=kind

## help: Show this help message
.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -e '^## ' | sed -e 's/^## //'
