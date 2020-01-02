FROM ubuntu:bionic 

# Maintainer
LABEL maintainer="Tony Pan <tcp1975@gmail.com>"

# Build arguments
ARG VCS_REF=master
ARG BUILD_DATE=""

# http://label-schema.org/rc1/
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Dropbox"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.description="Standalone Dropbox client on Linux"
LABEL org.label-schema.vcs-url="https://github.com/tcpan/docker-dropbox"
LABEL org.label-schema.vcs-ref="${VCS_REF}"

# Required to prevent warnings
ARG DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg2 software-properties-common gosu locales locales-all unzip build-essential tzdata \
 && apt-get autoclean -y && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Create user and group
RUN mkdir -p /opt/dropbox /opt/dropbox/.dropbox /opt/dropbox/Dropbox \
 && useradd --home-dir /opt/dropbox --comment "Dropbox Daemon Account" --user-group --shell /usr/sbin/nologin dropbox \
 && chown -R dropbox:dropbox /opt/dropbox

# Set language
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Generate locales
RUN sed --in-place '/en_US.UTF-8/s/^# //' /etc/locale.gen \
 && locale-gen

# Change working directory
WORKDIR /opt/dropbox/Dropbox

# Not really required for --net=host
EXPOSE 17500

# https://help.dropbox.com/installs-integrations/desktop/linux-repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FC918B335044912E \
 && add-apt-repository 'deb http://linux.dropbox.com/ubuntu bionic main' \
 && apt-get update \
 && apt-get install -y --no-install-recommends libatomic1 python3-gpg dropbox \
 && apt-get autoclean -y && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

RUN curl --location https://github.com/dark/dropbox-filesystem-fix/archive/master.zip > /tmp/dropbox-filesystem-fix.zip \
 && unzip /tmp/dropbox-filesystem-fix.zip -d /opt \
 && rm /tmp/dropbox-filesystem-fix.zip \
 && mv /opt/dropbox-filesystem-fix-master/ /opt/dropbox-filesystem-fix/ \
 && cd /opt/dropbox-filesystem-fix/ \
 && make \
 && chmod +x /opt/dropbox-filesystem-fix/dropbox_start.py

# Dropbox insists on downloading its binaries itself via 'dropbox start -i'
RUN echo "y" | gosu dropbox dropbox start -i

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /opt/dropbox/ and /tmp.
#
# https://bbs.archlinux.org/viewtopic.php?id=191001
RUN mkdir -p /opt/dropbox/bin/ \
 && mv /opt/dropbox/.dropbox-dist/* /opt/dropbox/bin/ \
 && rm -rf /opt/dropbox/.dropbox-dist \
 && install -dm0 /opt/dropbox/.dropbox-dist \
 && chmod u-w /opt/dropbox/.dropbox-dist \
 && chmod o-w /tmp \
 && chmod g-w /tmp

# Create volumes
VOLUME ["/opt/dropbox/.dropbox", "/opt/dropbox/Dropbox"]

# Install init script and dropbox command line wrapper
COPY docker-entrypoint.sh /

# Set entrypoint and command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/dropbox-filesystem-fix/dropbox_start.py"]
