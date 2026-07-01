FROM alpine:3.21

ARG PB_VERSION=0.36.2

RUN apk add --no-cache \
    unzip \
    wget \
    ca-certificates

RUN wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_arm64.zip" \
    -O /tmp/pocketbase.zip \
    && unzip /tmp/pocketbase.zip pocketbase -d /pb \
    && rm /tmp/pocketbase.zip \
    && chmod +x /pb/pocketbase

WORKDIR /pb
COPY pb_migrations ./pb_migrations

VOLUME /pb/pb_data

EXPOSE 8090

CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--hooksDir=pb_migrations"]
