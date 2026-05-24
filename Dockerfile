FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    git \
    jq \
    python3 \
    ca-certificates \
    wl-clipboard \
    xclip

ENV CAH_ROOT=/opt/cross-agent-handoff \
    PATH="/opt/cross-agent-handoff/bin:${PATH}"

WORKDIR /opt/cross-agent-handoff

COPY bin/ bin/
COPY lib/ lib/
COPY hooks/ hooks/
COPY templates/ templates/

RUN chmod +x bin/cross-agent-handoff \
    && chmod +x hooks/*.sh hooks/adapters/*.sh

COPY docker/entrypoint.sh /usr/local/bin/cah-entrypoint
RUN chmod +x /usr/local/bin/cah-entrypoint

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/cah-entrypoint"]
CMD ["--help"]
