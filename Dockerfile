FROM ruby:2.7-alpine

LABEL org.opencontainers.image.source https://github.com/kwatson/parking-notifier

RUN set -eux; \
        \
        apk add --no-cache \
                build-base \
                ca-certificates \
                curl \
                curl-dev \
                openssh \
                pcre \
                pcre-dev \
                tini

WORKDIR /mnt
COPY Gemfile /mnt
COPY Gemfile.lock /mnt
COPY ruby_job.sh /etc/periodic/15min/ruby_job

RUN chmod +x /etc/periodic/15min/ruby_job \
    && cd /mnt \
    && echo "[]" > /mnt/db.json \
    && bundle install

COPY email.html.erb /mnt
COPY main.rb /mnt

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/usr/sbin/crond", "-f", "-l", "8"]