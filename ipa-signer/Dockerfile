# --- build zsign ---
FROM debian:bookworm-slim AS zsign
RUN apt-get update && apt-get install -y --no-install-recommends git g++ make pkg-config libssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ARG ZSIGN_REF=9299685bab7ef99827e06e5dfda93af747386590
RUN git clone https://github.com/zhlynn/zsign.git /zsign \
    && cd /zsign && git checkout "$ZSIGN_REF" \
    && cd build/linux && make -j"$(nproc)"

# --- runtime ---
FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends openssl libssl3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=zsign /zsign/bin/zsign /usr/local/bin/zsign
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY static ./static
ENV DATA_DIR=/data PORT=8000
VOLUME /data
EXPOSE 8000
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT} --proxy-headers --forwarded-allow-ips='*'"]
