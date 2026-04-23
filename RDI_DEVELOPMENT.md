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

In Helm terms:

```bash
--set collector.image.registry=localhost:5050 \
--set collector.image.repository=redis/rdi-debezium-server \
--set collector.image.tag=0.0.0 \
--set collector.image.pullPolicy=Always
```

## 5. Repeat The Loop

After any code change:

1. rebuild the Maven distro
2. rebuild the image
3. push the image to `localhost:5050`
4. redeploy or restart the collector in `redis-data-integration`

## Notes

- This image path is intentionally close to upstream Debezium container behavior.
- The local image is built from the branch-produced `debezium-server-dist` tarball, not from Maven Central.
- Release and CI image publishing use the `RDI Build` GitHub Actions workflow in this repo.
