FROM node:20-bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/sdqmd/grep-trace-pwn
LABEL org.opencontainers.image.description="grep, trace, pwn: intentionally vulnerable Flask + Express targets"

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-pip iputils-ping curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY flask_app/requirements.txt flask_app/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r flask_app/requirements.txt

COPY express_app/package.json express_app/package.json
RUN cd express_app && npm install --omit=dev --no-audit --no-fund

COPY flask_app flask_app
COPY express_app express_app
COPY flask_app_fixed flask_app_fixed
COPY express_app_fixed express_app_fixed
RUN ln -s /app/express_app/node_modules /app/express_app_fixed/node_modules
COPY secret secret
COPY start.sh start.sh
RUN chmod +x start.sh

EXPOSE 5000 3000 5002 3002
CMD ["./start.sh"]
