FROM iron-meridian-candidate:484d98d958a0
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
COPY health_runner.py /app/health_runner.py
USER game
CMD ["python3", "/app/health_runner.py"]
