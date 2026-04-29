# RDI Development

This document describes the simplest local development loop for `debezium-server` on the RDI release branches.

## Scope

These instructions are for:

- building the current branch locally
- creating a local Debezium Server image
- pushing it to the local kind registry
- using that image from `redis-data-integration`

The examples below assume:

- branch: `rdi/3.5`
- local registry: `localhost:5050`
- local image: `localhost:5050/redis/rdi-debezium-server:0.0.0`

## Prerequisites

- Java 21
- Docker
- Maven wrapper support from this repo
- a local registry on `localhost:5050`

If you are using the `redis-data-integration` kind environment, that registry is normally already present.

## 1. Build The Distribution

From the `debezium-server` repo root:

```bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk use java 21.0.9-amzn >/dev/null
./mvnw clean install -fae -Passembly-rdi -DskipTests -DskipITs -DskipNonCore
```

This produces:

```text
debezium-server-dist/target/debezium-server-dist-3.5.0.Final.tar.gz
```

## 2. Build The Local Image

From the same repo root:

```bash
SERVER_DIST_TARBALL="$(find debezium-server-dist/target -maxdepth 1 -name 'debezium-server-dist-*.tar.gz' | head -n1)"

docker build \
  -f container/server/3.5/Dockerfile \
  --build-arg SERVER_DIST_TARBALL="${SERVER_DIST_TARBALL}" \
  -t localhost:5050/redis/rdi-debezium-server:0.0.0 \
  .
```

This keeps the image build tied to the exact branch artifact that was just produced, even after the line advances from `3.5.0.Final` to `3.5.1.Final`.

You can verify the selected tarball with:

```text
echo "$SERVER_DIST_TARBALL"
```

## 3. Push The Image To The Local Registry

```bash
docker push localhost:5050/redis/rdi-debezium-server:0.0.0
```

## 4. Use The Image From `redis-data-integration`

Point the collector image at:

```text
registry: localhost:5050
repository: redis/rdi-debezium-server
tag: 0.0.0
```

For the local k3s setup path used by `redis-data-integration`, export:

```bash
export DBZ_IMAGE_REGISTRY=localhost:5050
export DBZ_IMAGE_REPOSITORY=redis/rdi-debezium-server
export DBZ_IMAGE_VERSION=0.0.0
```

Then run the normal local setup:

```bash
cd /path/to/redis-data-integration
k8s/dev/setup.sh --rdi-db-password test --rdi-version 0.0.0
```

That path will:

- pull `${DBZ_IMAGE_REGISTRY}/${DBZ_IMAGE_REPOSITORY}:${DBZ_IMAGE_VERSION}`
- import it into k3s/containerd
- render the collector image override into the deployed resources

If you need the raw Helm override form, the current keys are:

```bash
--set operator.dataPlane.collector.image.registry=localhost:5050 \
--set operator.dataPlane.collector.image.repository=redis/rdi-debezium-server \
--set operator.dataPlane.collector.image.tag=0.0.0 \
--set operator.dataPlane.collector.image.pullPolicy=Always
```

## 5. Validate In GitHub CI

The `redis-data-integration` validation path is the `full_ci` workflow with explicit Debezium image coordinates.

Workflow:

- repository: `RedisLabs/redis-data-integration`
- workflow: `full_ci.yml`
- branch: typically `feat/dbz-3.5.0-upgrade-split` for Debezium upgrade validation

Inputs:

```text
dbz_image_registry=artifactory.dev.redislabs.com
dbz_image_repository=rdi-docker-dev/debezium-server
dbz_image_tag=<branch-image-tag>
```

Example:

```text
dbz_image_registry=artifactory.dev.redislabs.com
dbz_image_repository=rdi-docker-dev/debezium-server
dbz_image_tag=rdi-3.5-bc81d5ece0d5
```

This is the same override path consumed by:

- `build-rdi-packages`
- `test-all`
- smoke Helm jobs
- the shared e2e setup action

## 6. Repeat The Loop

After any code change:

1. rebuild the Maven distro
2. rebuild the image
3. push the image to `localhost:5050`
4. redeploy or restart the collector in `redis-data-integration`

## 7. CI Publishing

The `RDI Build` GitHub Actions workflow is the branch and release publishing path for this repo.

- push to `rdi/*`:
  - builds the distro and image
  - pushes a branch image to Artifactory
  - branch image tag format: `rdi-<line>-<sha12>`
- push a tag matching `v*.Final-rdi.*`:
  - builds the distro and image
  - pushes the release image to Docker Hub
  - release image tag format: `<version>.Final-rdi.<n>`
- `workflow_dispatch` in `debezium-server`:
  - can run as a build-only validation
  - can push an image when `push_image=true`
  - can override the published tag with `image_tag`

Current image targets:

- branch builds:
  - `artifactory.dev.redislabs.com/rdi-docker-dev/debezium-server:rdi-3.5-<sha12>`
- release tags:
  - `docker.io/redislabs/debezium-server:3.5.0.Final-rdi.1`

## 8. Core Mapping

`debezium-server` is built together with the mapped `debezium` core line, not against Maven Central artifacts alone.

For `rdi/3.5`:

- server repo: `redislabsdev/debezium-server`
- core repo: `redislabsdev/debezium`
- core ref: `rdi/3.5`

The mapping lives in `.github/rdi-core-mapping.json`.

## 9. Release Checklist

1. Push the desired commit to `rdi/3.5`.
2. Verify the branch `RDI Build` run publishes the expected Artifactory image.
3. Validate `redis-data-integration` against that branch image if needed.
4. Create the release tag `v<version>.Final-rdi.<n>`.
5. Verify the tag `RDI Build` run publishes the Docker Hub release image.
6. Update downstream consumers to the published release tag when ready.

## Notes

- This image path is intentionally close to upstream Debezium container behavior.
- The local image is built from the branch-produced `debezium-server-dist` tarball, not from Maven Central.
- Release and CI image publishing use the `RDI Build` GitHub Actions workflow in this repo.
- The current `assembly-rdi` profile is intended to match the effective shipped surface from `origin/3.3.1-final` while pruning unused modules for CVE hygiene.
- The resulting `3.5.0.Final` tarball is still larger than the `3.3.1.Final` tarball:
  - `3.3.1-final`: `197,220,827` bytes
  - `3.5.0` `assembly-rdi`: `212,906,208` bytes
- Most of the size increase is from newer upstream `3.5.0` runtime dependencies, especially the Quarkus/Netty/Kubernetes stack, plus about `2.6 MB` from the SQL Server MSAL runtime subtree added for Azure SQL service principal authentication.
