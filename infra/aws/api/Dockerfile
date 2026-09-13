FROM iron-meridian-api:0.38-484d98d9
USER root
RUN pip install --no-cache-dir boto3==1.40.30
COPY entrypoint.py /app/aws_entrypoint.py
COPY migrate_data.py /app/migrate_data.py
USER appuser
CMD ["python", "/app/aws_entrypoint.py"]
