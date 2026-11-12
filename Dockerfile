# syntax=docker/dockerfile:1

# --- build stage: compiled artifacts only, discarded after copy ---
FROM ghcr.io/linuxserver/baseimage-alpine:3.22 AS build

ARG THELOUNGE_VERSION

RUN \
  apk add --no-cache \
    build-base \
    git \
    curl \
    jq \
    py3-setuptools \
    python3-dev \
    nodejs \
    npm

RUN \
  if [ -z ${THELOUNGE_VERSION+x} ]; then \
    THELOUNGE_VERSION=$(curl -sX GET "https://api.github.com/repos/thelounge/thelounge/releases/latest" | jq -r '. | .tag_name'); \
  fi && \
  mkdir -p /app/thelounge && \
  curl -o /tmp/thelounge.tar.gz -L \
    "https://github.com/tetrahydroc/thelounge/archive/master.tar.gz" && \
  tar xf /tmp/thelounge.tar.gz -C /app/thelounge --strip-components=1

WORKDIR /app/thelounge

RUN \
  git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
  sed -i "s/public: false,/public: true,/g" defaults/config.js && \
  npm install -g corepack && \
  yarn install && \
  NODE_ENV=production yarn build && \
  echo "**** prune devDependencies, keep only production node_modules ****" && \
  npm prune --omit=dev && \
  yarn cache clean

# --- final stage: runtime only, no build tools/toolchain ---
FROM ghcr.io/linuxserver/baseimage-alpine:3.22

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca,nemchik"

# environment settings
ENV THELOUNGE_HOME="/config"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    nodejs

COPY --from=build /app/thelounge /app/thelounge

RUN \
  echo "**** link thelounge binary (no npm needed at runtime) ****" && \
  chmod +x /app/thelounge/index.js && \
  ln -s /app/thelounge/index.js /usr/local/bin/thelounge && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 9000
VOLUME /config
