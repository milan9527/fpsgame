FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libfontconfig1 libx11-6 libxcursor1 libxinerama1 libgl1 libxi6 libxrandr2 libasound2 libpulse0 libvulkan1 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --uid 10001 --create-home game
COPY tools/godot /usr/local/bin/godot
COPY client /app/client
RUN godot --headless --path /app/client --editor --import > /tmp/import.log 2>&1 && ! grep -q "SCRIPT ERROR" /tmp/import.log && mkdir -p /home/game/.local/share/godot/app_userdata && chown -R game:game /app /home/game
USER game
WORKDIR /app/client
CMD ["godot", "--headless", "--path", "/app/client", "--", "--server"]
