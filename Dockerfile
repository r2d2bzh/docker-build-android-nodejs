FROM ubuntu:22.04

ONBUILD ARG UID=1001
ONBUILD ARG GID=1001

ARG JAVA_VERSION=17
ARG NODEJS_VERSION=20
# See https://developer.android.com/studio/index.html#command-tools
ARG ANDROID_SDK_VERSION=9477386
# See https://developer.android.com/tools/releases/build-tools
ARG ANDROID_BUILD_TOOLS_VERSION=34.0.0
# See https://developer.android.com/studio/releases/platforms
ARG ANDROID_PLATFORMS_VERSION=34
# See https://gradle.org/releases/
ARG GRADLE_VERSION=8.2

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

WORKDIR /tmp

RUN apt-get update -q

# General packages
RUN apt-get install -qy \
        sudo \
        apt-utils \
        locales \
        gnupg2 \
        build-essential \
        curl \
        usbutils \
        libssl-dev \
        git \
        unzip \
        p7zip p7zip-full \
        python3 \
        gettext-base \
        openjdk-${JAVA_VERSION}-jre \
        openjdk-${JAVA_VERSION}-jdk

RUN apt-get install -qy \
        libreadline-dev \
        zlib1g-dev \
        # Fastlane plugins dependencies
        # - fastlane-plugin-badge (curb)
        libcurl4 libcurl4-openssl-dev \
        # ruby-setup dependencies
        libyaml-0-2 \
        libgmp-dev \
        file

# Set locale
RUN locale-gen en_US.UTF-8 && update-locale

# Install Gradle
ENV GRADLE_HOME=/opt/gradle
RUN mkdir $GRADLE_HOME \
        && curl -sL https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o gradle-${GRADLE_VERSION}-bin.zip \
        && unzip -d $GRADLE_HOME gradle-${GRADLE_VERSION}-bin.zip
ENV PATH=$PATH:/opt/gradle/gradle-${GRADLE_VERSION}/bin

# Install Android SDK tools
ENV ANDROID_HOME=/opt/android-sdk
RUN curl -sL https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip -o commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip \
        && unzip commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip \
        && mkdir $ANDROID_HOME && mv cmdline-tools $ANDROID_HOME \
        && yes | $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME --licenses \
        && $ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" "platforms;android-${ANDROID_PLATFORMS_VERSION}"
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}

# Install NodeJS
RUN curl -sL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash - \
        && apt-get update -q && apt-get install -qy nodejs
ENV NPM_CONFIG_PREFIX=${HOME}/.npm-global
ENV PATH=$PATH:${HOME}/.npm-global/bin

## Install rbenv
ENV RBENV_ROOT "/usr/local/rbenv"
RUN git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT
ENV PATH "$PATH:$RBENV_ROOT/bin"
ENV PATH "$PATH:$RBENV_ROOT/shims"

# Install ruby-build (rbenv plugin)
RUN mkdir -p "$RBENV_ROOT"/plugins
RUN git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT"/plugins/ruby-build

# Install ruby envs
RUN echo “install: --no-document” > ~/.gemrc
ENV RUBY_CONFIGURE_OPTS=--disable-install-doc
RUN rbenv install 3.1.1

# Setup default ruby env
RUN rbenv global 3.1.1
RUN gem install bundler:2.3.7

# Clean up
RUN apt-get autoremove -y \
        && apt-get clean -y \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/*

ONBUILD RUN \
        echo "user:x:$UID:$GID::/home/user:" >> /etc/passwd && \
        echo "user:!:$(($(date +%s) / 60 / 60 / 24)):0:99999:7:::" >> /etc/shadow && \
        echo "user:x:$GID:" >> /etc/group && \
        mkdir -p /home/user && chown user: /home/user && \
        echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/user && \
        chown -R user:user ${ANDROID_HOME}

WORKDIR /home/user

ENTRYPOINT []