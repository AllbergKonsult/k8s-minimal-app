# Based on https://github.com/vincentbernat/hellogopher/tree/feature/go-mod
#
VERSION              = $(shell git describe --tags --always --dirty --match=v* 2> /dev/null)
PKGS                 = ./...

GO                   = go
GOIMPORTS            = goimports
GOLINT               = golint

PACKAGE              = bin/app

DOCKER               = docker
DOCKER_NETWORK      ?= bridge
DELIVERABLE_IMG_TAG ?= app

GO111MODULE          = on
GOPROXY             ?=
CGO_ENABLED          = 0

USER_ID              = $(shell id -u)

export GO111MODULE GOPROXY

# The default build target builds the project on the local machine.
.PHONY: build
build: goimports golint go-vet go-deps go-test go-build go-mod-tidy

# The docker-build target builds the project inside a Docker container.
.PHONY: docker-build
docker-build:
	@echo "Running $(DOCKER) build..."
	$(DOCKER) build \
		-f build/package/Dockerfile \
		-t ${DELIVERABLE_IMG_TAG} \
		.

# The docker-build target builds the project inside a Docker container.
.PHONY: dockerx-build
dockerx-build:
	@echo "Running $(DOCKER) buildx..."
	$(DOCKER) buildx build \
		--load \
		-f build/package/Dockerfile \
		-t ${DELIVERABLE_IMG_TAG} \
		--platform linux/arm/v7,linux/arm64/v8,linux/amd64 \
		.

# Formats the source code.
.PHONY: goimports
goimports: tools.goimports
	@echo "Running $(GOIMPORTS)..."
	@ret=0 && for f in $$(find . -type f -name '*.go' -not -path "./pkg/mod/golang.org/*" -not -path "./pkg/mod/github.com/*" -not -path "./_tmp/*" -not -path "*.pb.go"); do \
		$(GOIMPORTS) -l -w $$f || ret=$$? ; \
	done ; exit $$ret

# Lints the source code.
.PHONY: golint
golint: tools.golint
	@echo "Running $(GOLINT)..."
	@ret=0 && for d in $$($(GO) list $(PKGS) | grep -v golang.org/ | grep -v github.com/); do \
		$(GOLINT) -set_exit_status $${d} || ret=$$? ; \
	done ; exit $$ret

# Performs simple static analysis on the source code.
.PHONY: go-vet
go-vet:
	@echo "Running $(GO) vet..."
	@$(GO) vet ./...

# Gets all our dependencies.
.PHONY: go-deps
go-deps:
	@echo "Running $(GO) get..."
	@$(GO) get -d $(PKGS)

# Runs unit tests.
.PHONY: go-test
go-test:
	@echo "Running $(GO) test..."
	@$(GO) test -v $(PKGS)

# Runs integration tests.
.PHONY: go-test-integration
go-test-integration:
	@echo "Running $(GO) test..."
	@$(GO) test -v $(PKGS) -tags=integration

# Builds the application.
.PHONY: go-build
go-build:
	@echo "Running $(GO) build..."
	@$(GO) build -a -installsuffix cgo -o $(PACKAGE) ./

# Tidies up the Go modules file post-build. Needed for clean Docker builds.
.PHONY: go-mod-tidy
go-mod-tidy:
	@echo "Running $(GO) mod tidy..."
	@$(GO) mod tidy

# Cleans the compiled binary.
.PHONY: clean
clean:
	@rm -f $(PACKAGE)

# Convert the current sites.txt to the new sites.json
.PHONY: convert-sites
convert-sites:
	@FilesDirectory=test-data/s3-data/ $(PACKAGE) --convertsites=true

# Cleans up the builder Docker image.
.PHONY: docker-clean
docker-clean: docker-rmi-builder docker-rmi-deliverable

# Installs required tools.
.PHONY: tools tools.goimports tools.golint
tools: tools.goimports tools.golint

# Installs goimports.
tools.goimports:
	@command -v $(GOIMPORTS) >/dev/null ; if [ $$? -ne 0 ]; then \
		echo "Installing goimports..."; \
		$(GO) install golang.org/x/tools/cmd/goimports@latest; \
	fi

# Installs golint.
tools.golint:
	@command -v $(GOLINT) >/dev/null ; if [ $$? -ne 0 ]; then \
		echo "Installing golint..."; \
		$(GO) install golang.org/x/lint/golint@latest; \
	fi

# Checks license
.PHONY: check-licenses
check-licenses:
ifndef GITHUB_TOKEN
	$(error GITHUB_TOKEN is undefined)
endif
	@pushd licenseManagement && \
 		go run main.go --github-token "${GITHUB_TOKEN}" --modfile "../go.mod" > output.txt && \
 		grep '|' output.txt > licenses.md
