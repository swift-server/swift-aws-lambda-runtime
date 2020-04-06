FROM fabianfett/amazonlinux-swift:5.2-amazonlinux2

RUN yum -y install \
    git \
    libuuid-devel \
    libicu-devel \
    libedit-devel \
    libxml2-devel \
    sqlite-devel \
    python-devel \
    ncurses-devel \
    curl-devel \
    tzdata \
    libtool \
    libatomic\
    gcc-c++ \
    jq \
    tar \
    zip
