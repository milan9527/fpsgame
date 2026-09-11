# Build with the verified candidate's IronMeridian-Linux directory as context.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1 libx11-6 libxcursor1 libxinerama1 libgl1 libxi6 libxrandr2 libasound2 libpulse0 libvulkan1 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --uid 10001 --create-home game
WORKDIR /app
COPY IronMeridian IronMeridian.pck build.json ./
RUN chmod 755 /app/IronMeridian && mkdir -p /home/game/.local/share/godot/app_userdata && chown -R game:game /home/game
USER game
CMD ["/app/IronMeridian", "--headless", "--main-pack", "/app/IronMeridian.pck", "--", "--server"]
