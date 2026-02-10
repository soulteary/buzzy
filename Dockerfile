# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t buzzy .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name buzzy buzzy

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.7
FROM ghcr.io/ruby/ruby:$RUBY_VERSION-noble AS base

# Rails app lives here
WORKDIR /rails

RUN set -eux; \
    file="/etc/apt/sources.list.d/ubuntu.sources"; \
    base="https://mirrors.tuna.tsinghua.edu.cn"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64|i386) repo="ubuntu" ;; *) repo="ubuntu-ports" ;; esac; \
    sed -E -i "s|^URIs:\s*.*$|URIs: ${base}/${repo}|g" "$file"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 libssl-dev && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config ca-certificates curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy dependency manifests and vendored gems.
# Keep vendor nested under /rails/vendor so path gems resolve.
COPY Gemfile Gemfile.lock ./
COPY vendor/ ./vendor/

# Install application gems
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Image metadata
ARG OCI_DESCRIPTION
LABEL org.opencontainers.image.description="${OCI_DESCRIPTION}"
ARG OCI_SOURCE
LABEL org.opencontainers.image.source="${OCI_SOURCE}"
LABEL org.opencontainers.image.licenses="O'Saasy"

# Run and own only the runtime files as a non-root user for security
# Only create group/user when missing so we don't conflict with base image (e.g. GID 1000 in noble)
RUN (getent group rails > /dev/null 2>&1 || groupadd --system rails) && \
    (getent passwd rails > /dev/null 2>&1 || useradd rails --gid rails --create-home --shell /bin/bash)
USER rails:rails

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# 以 rails 用户创建运行时目录（含 storage.oss.yml 的 local/test root），避免首次启动时权限问题
RUN mkdir -p log storage tmp/pids tmp/storage tmp/storage/files \
    storage/development/files storage/test/files storage/production/files

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]

