ARG PYTHON_VERSION=3.14-trixie
FROM python:${PYTHON_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --fix-missing && apt-get install -qy --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq \
    rsync \
    ruby \
	  ruby-rubygems \
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

# avoid million NPM install messages
ENV npm_config_loglevel=warn
# allow installing when the main user is root
ENV npm_config_unsafe_perm=true
# disable NPM funding messages
ENV npm_config_fund=false
