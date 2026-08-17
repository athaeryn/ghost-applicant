FROM ruby:3.4-slim-bookworm

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libsqlite3-dev \
      curl \
      git \
    && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/bundle

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["./bin/dev"]