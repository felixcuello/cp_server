# syntax = docker/dockerfile:1

# This Dockerfile supports both production and development modes
# For production: docker build -t my-app .
# For development: docker build --build-arg RAILS_ENV=development --build-arg BUNDLE_DEPLOYMENT=0 --build-arg WORKDIR_PATH=/app -t my-app .

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.2.2
ARG RAILS_ENV=production
ARG BUNDLE_DEPLOYMENT=1
ARG BUNDLE_WITHOUT=development
ARG WORKDIR_PATH=/rails
ARG RAILS_MASTER_KEY

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here (use /app for dev, /rails for prod)
ARG WORKDIR_PATH
WORKDIR ${WORKDIR_PATH}

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      sqlite3 \
      python3 \
      nodejs \
      gcc g++ make \
      default-mysql-client \
      default-libmysqlclient-dev \
      # nsjail dependencies (needed for code execution isolation)
      autoconf \
      bison \
      flex \
      git \
      libprotobuf-dev \
      libnl-route-3-dev \
      libtool \
      pkg-config \
      protobuf-compiler \
      uidmap && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Build and install nsjail from source (needed for secure code execution)
RUN git clone --depth 1 https://github.com/google/nsjail.git /tmp/nsjail && \
    cd /tmp/nsjail && \
    make && \
    mv /tmp/nsjail/nsjail /usr/local/bin/ && \
    rm -rf /tmp/nsjail

# Create chroot directory structure for isolated execution
RUN mkdir -p /chroot && \
    mkdir -p /chroot/bin && \
    mkdir -p /chroot/lib && \
    mkdir -p /chroot/lib64 && \
    mkdir -p /chroot/usr && \
    mkdir -p /chroot/usr/bin && \
    mkdir -p /chroot/usr/lib && \
    mkdir -p /chroot/tmp && \
    mkdir -p /chroot/workspace && \
    mkdir -p /chroot/etc && \
    chmod 1777 /chroot/tmp

# Copy shell and basic utilities to chroot
RUN cp /bin/sh /chroot/bin/ && \
    cp /bin/dash /chroot/bin/ 2>/dev/null || true && \
    ldd /bin/sh | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/lib/ 2>/dev/null || true

# Copy required binaries and libraries for Python
RUN cp /usr/bin/python3 /chroot/usr/bin/ && \
    ldd /usr/bin/python3 | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/usr/lib/ 2>/dev/null || true

# Copy Python libraries
RUN cp -r /usr/lib/python3* /chroot/usr/lib/ 2>/dev/null || true

# Copy required binaries and libraries for Node.js
RUN cp /usr/bin/node /chroot/usr/bin/ && \
    ldd /usr/bin/node | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/usr/lib/ 2>/dev/null || true

# Copy required binaries and libraries for Ruby
RUN cp /usr/local/bin/ruby /chroot/usr/bin/ && \
    ldd /usr/local/bin/ruby | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/usr/lib/ 2>/dev/null || true && \
    cp -r /usr/local/lib/ruby /chroot/usr/lib/ 2>/dev/null || true

# Copy GCC and G++ for compiled languages
RUN cp /usr/bin/gcc /chroot/usr/bin/ && \
    cp /usr/bin/g++ /chroot/usr/bin/ && \
    cp /usr/bin/as /chroot/usr/bin/ && \
    cp /usr/bin/ld /chroot/usr/bin/ && \
    ldd /usr/bin/gcc | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/usr/lib/ 2>/dev/null || true && \
    ldd /usr/bin/g++ | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /chroot/usr/lib/ 2>/dev/null || true

# Copy essential libraries
RUN cp -r /lib/x86_64-linux-gnu/* /chroot/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/x86_64-linux-gnu/* /chroot/usr/lib/ 2>/dev/null || true && \
    cp -r /lib64/* /chroot/lib64/ 2>/dev/null || true

# Fix the dynamic linker symlink to use relative path
RUN rm -f /chroot/lib64/ld-linux-x86-64.so.2 && \
    ln -s ../lib/ld-linux-x86-64.so.2 /chroot/lib64/ld-linux-x86-64.so.2

# Create a nobody user in chroot (for running untrusted code)
RUN echo "nobody:x:65534:65534:Nobody:/:/bin/false" > /chroot/etc/passwd

# Set environment variables
ARG RAILS_ENV
ARG BUNDLE_DEPLOYMENT
ARG BUNDLE_WITHOUT
ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_DEPLOYMENT=${BUNDLE_DEPLOYMENT} \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT}

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
ARG RAILS_ENV
RUN if [ "$RAILS_ENV" = "production" ]; then \
      SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile; \
    fi

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
ARG WORKDIR_PATH
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build ${WORKDIR_PATH} ${WORKDIR_PATH}

# Create rails user (needed for production, harmless for development)
RUN groupadd --system --gid 1000 rails 2>/dev/null || true && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash 2>/dev/null || true

# For production: set ownership and switch to rails user
# For development: keep root user (needed for nsjail operations)
ARG RAILS_ENV
RUN if [ "$RAILS_ENV" = "production" ]; then \
      chown -R rails:rails db log storage tmp ${WORKDIR_PATH}; \
    fi

# Default to root user (development needs it for nsjail)
# Production entrypoint will switch to rails user
USER root

# Entrypoint: production uses docker-entrypoint, development just passes through
ARG RAILS_ENV
ARG WORKDIR_PATH
RUN echo '#!/bin/sh\n\
if [ "$RAILS_ENV" = "production" ] && [ -f '"${WORKDIR_PATH}"'/bin/docker-entrypoint ]; then\n\
  exec '"${WORKDIR_PATH}"'/bin/docker-entrypoint "$@"\n\
else\n\
  exec "$@"\n\
fi' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
