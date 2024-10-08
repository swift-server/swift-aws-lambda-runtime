ARG swift_version=6.0
ARG base_image=swift:$swift_version-amazonlinux2
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version

# dependencies
RUN yum install -y wget perl-Digest-SHA
RUN yum install -y lsof dnsutils netcat-openbsd net-tools curl jq # used by integration tests

# tools
RUN mkdir -p $HOME/.tools
RUN echo 'export PATH="$HOME/.tools:$PATH"' >> $HOME/.profile
