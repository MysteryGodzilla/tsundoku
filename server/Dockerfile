# The Tsundoku sync server (docs/sync-server.md).
# Build from the repository root, which compose.yaml does for you:
#   docker compose up -d --build
# or by hand:
#   docker build -f server/Dockerfile -t tsundoku-server .

FROM dart:3.14 AS build
WORKDIR /src
# The shared protocol package first, then the server's dependencies, so they're cached.
COPY packages/tsundoku_protocol/ packages/tsundoku_protocol/
COPY server/pubspec.yaml server/pubspec.lock server/
WORKDIR /src/server
RUN dart pub get
COPY server/ ./
# One program plus its own copy of SQLite, in /out/bundle (bin/ and lib/).
RUN dart pub get --offline && dart build cli -o /out

FROM debian:trixie-slim
RUN useradd --system --uid 10001 --home-dir /data tsundoku \
 && mkdir -p /data \
 && chown tsundoku /data
COPY --from=build /out/bundle/ /opt/tsundoku/
ENV PATH="/opt/tsundoku/bin:${PATH}"
USER tsundoku
# The database and its daily backups live here: keep it in a volume.
WORKDIR /data
VOLUME /data
EXPOSE 8797
HEALTHCHECK --interval=1m --timeout=10s --start-period=15s CMD ["tsundoku_server", "health"]
ENTRYPOINT ["tsundoku_server"]
# Inside the container it listens on every network, so Docker can pass connections in. Which
# networks outside can reach it is set by "ports" in compose.yaml.
CMD ["serve", "--host", "0.0.0.0", "--port", "8797", "--db", "/data/tsundoku.db", "--backups", "/data/backups"]
