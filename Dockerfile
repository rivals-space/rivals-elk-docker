FROM docker.io/library/node:lts-alpine AS base

# Prepare work directory
WORKDIR /elk

ARG ELK_VERSION
FROM base AS builder

# Prepare pnpm https://pnpm.io/installation#using-corepack
RUN corepack enable

# Prepare deps
RUN apk update
RUN apk add git --no-cache

ADD patches /patches

RUN set -eux; \
    git clone https://github.com/elk-zone/elk.git /elk; \
    git checkout v${ELK_VERSION}; \
    git apply --stat /patches/v${ELK_VERSION}.diff; \
    git apply /patches/v${ELK_VERSION}.diff

RUN pnpm i --frozen-lockfile

# Build
RUN pnpm build

FROM base AS runner

ARG UID=911
ARG GID=911

# Create a dedicated user and group
RUN set -eux; \
    addgroup -g $UID elk; \
    adduser -u $GID -D -G elk elk;

USER elk

ENV NODE_ENV=production

COPY --from=builder /elk/.output ./.output

EXPOSE 5314/tcp

ENV PORT=5314

# Specify container only environment variables ( can be overwritten by runtime env )
ENV NUXT_STORAGE_FS_BASE='/elk/data'

# Persistent storage data
VOLUME [ "/elk/data" ]

CMD ["node", ".output/server/index.mjs"]
