ARG GAME_BASE=632930644527.dkr.ecr.us-east-1.amazonaws.com/iron-meridian-game@sha256:1ed7b362ddc8f8912a199181112eff9b2a62f0312d65c9ee57d1a9078b578196
FROM ${GAME_BASE}
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
COPY health_runner.py /app/health_runner.py
COPY network_bootstrap.gd /app/network_bootstrap.gd
RUN chmod 644 /app/health_runner.py /app/network_bootstrap.gd
USER game
CMD ["python3", "/app/health_runner.py"]
