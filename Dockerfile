FROM python:3.12-slim

LABEL org.opencontainers.image.source=https://github.com/sdqmd/grep-trace-pwn
LABEL org.opencontainers.image.description="grep, trace, pwn: intentionally vulnerable Flask target"

RUN apt-get update \
 && apt-get install -y --no-install-recommends iputils-ping curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY flask_app/requirements.txt flask_app/requirements.txt
RUN pip install --no-cache-dir -r flask_app/requirements.txt

COPY flask_app flask_app
COPY secret secret
COPY start.sh start.sh
RUN chmod +x start.sh

EXPOSE 5000
CMD ["./start.sh"]
