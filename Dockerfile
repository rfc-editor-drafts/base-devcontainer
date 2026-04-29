ARG PYTHON_VERSION=3.14-trixie

# ==========================================
# BUILDER IMAGE
# ==========================================
FROM python:${PYTHON_VERSION} AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --fix-missing && apt-get install -qy --no-install-recommends \
    libfl-dev \
    flex \
    yacc

RUN mkdir /builder \
 && cd /builder \
 && git clone https://github.com/ietf-tools/bap.git \
 && cd bap \
 && ./configure \
 && make \
 && cp bap htmlwdiff prep /usr/local/bin

# ==========================================
# FINAL IMAGE
# ==========================================
FROM python:${PYTHON_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --fix-missing && apt-get install -qy --no-install-recommends \
    aspell \
    aspell-en \
    ca-certificates \
    curl \
    gawk \
    gnupg \
    jq \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libharfbuzz-subset0 \
    poppler-utils \
    rsync \
    ruby \
    ruby-rubygems \
    wdiff \
    wget \
    # Remove imagemagick due to https://security-tracker.debian.org/tracker/CVE-2019-10131
    && apt-get purge -y imagemagick imagemagick-6-common

# Install kramdown-rfc2629 (ruby)
RUN gem install kramdown-rfc2629

# Temporary: Upgrade python packages due to https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2022-40897 and https://github.com/advisories/GHSA-2mqj-m65w-jghx
# They are installed by the base image (python) which does not have the patch.
RUN python3 -m pip install --upgrade \
    setuptools==78.1.1 \
    gitpython==3.1.41

# Add python dependencies
COPY requirements.txt /tmp/pip-tmp/
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements.txt \
    && rm -rf /tmp/pip-tmp

# Silence npm warnings
ENV npm_config_loglevel=warn
ENV npm_config_unsafe_perm=true
ENV npm_config_fund=false

# Add python scripts
COPY --from=builder /usr/local/bin/bap /usr/local/bin/bap
COPY --from=builder /usr/local/bin/htmlwdiff /usr/local/bin/htmlwdiff
COPY --from=builder /usr/local/bin/prep /usr/local/bin/prep

RUN curl -s -o /usr/local/bin/rfcstrip https://raw.githubusercontent.com/mbj4668/rfcstrip/refs/heads/master/rfcstrip \
    && chmod 755 /usr/local/bin/rfcstrip

RUN curl -s -o /usr/local/bin/rfcdiff https://raw.githubusercontent.com/ietf-tools/rfcdiff/refs/heads/main/rfcdiff \
    && chmod 755 /usr/local/bin/rfcdiff

COPY scripts/newdupe /usr/local/bin/newdupe
COPY scripts/newspell /usr/local/bin/newspell

# Add editor user/group
RUN groupadd --force --gid 1000 editor && \
    useradd -s /bin/bash --uid 1000 --gid 1000 -m editor

RUN mkdir -p /workspace
WORKDIR /workspace

# -------------------------------------
# Switch to user mode
# -------------------------------------
USER editor:editor

# Add aspell
COPY files/aspell.en.pws /home/editor/.aspell.en.pws

# Install required fonts
RUN mkdir -p ~/.fonts/opentype /tmp/fonts && \
    wget -q -O /tmp/fonts.tar.gz https://github.com/ietf-tools/xml2rfc-fonts/archive/refs/tags/3.22.0.tar.gz && \
    tar zxf /tmp/fonts.tar.gz -C /tmp/fonts && \
    mv /tmp/fonts/*/noto/* ~/.fonts/opentype/ && \
    mv /tmp/fonts/*/roboto_mono/* ~/.fonts/opentype/ && \
    rm -rf /tmp/fonts.tar.gz /tmp/fonts/ && \
    fc-cache -f

# Install aasvg
RUN npm install -g aasvg@0.4.3
