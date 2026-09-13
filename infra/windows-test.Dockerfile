FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 wine xvfb xauth libgl1-mesa-dri libglx-mesa0 fonts-dejavu-core ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home tester
USER tester
ENV WINEDEBUG=-all WINEPREFIX=/home/tester/.wine
WORKDIR /work
