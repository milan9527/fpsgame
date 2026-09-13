# Disposable remote-client verifier; not a production service.
FROM iron-meridian-candidate:484d98d958a0
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 openssh-client && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["python3"]
