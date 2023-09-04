ARG BASE_IMAGE=nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

# create a non-root user wih sudo
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# basic dependencies
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    build-essential vim less git git-lfs wget curl apt-utils software-properties-common \
    iputils-ping dnsutils traceroute \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# set up ssh access
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    ssh tmux openssh-server htop nvtop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ARG SSH_PUBKEY
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config \
    && sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#UsePAM yes/UsePAM no/' /etc/ssh/sshd_config \
    && sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config \
    && sed -i 's/#PrintMotd yes/PrintMotd no/' /etc/ssh/sshd_config \
    && sed -i 's/#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config \
    && sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/' /etc/ssh/sshd_config \
    && sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/' /etc/ssh/sshd_config \
    && sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config \
    && sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config \
    && sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config \
    && sed -i 's/#MaxSessions 10/MaxSessions 3/' /etc/ssh/sshd_config \
    && sed -i 's/#MaxStartups 10:30:100/MaxStartups 3/' /etc/ssh/sshd_config
RUN mkdir /home/${USERNAME}/.ssh \
    && echo "${SSH_PUBKEY}" > /home/${USERNAME}/.ssh/authorized_keys \
    && chmod 700 /home/${USERNAME}/.ssh \
    && chmod 600 /home/${USERNAME}/.ssh/authorized_keys \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh
RUN service ssh start
EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]

# setup locale
ENV LANG=en_US.UTF-8
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends locales \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN locale-gen ${LANG} \
    && dpkg-reconfigure locales \
    && update-locale LANG=${LANG} LC_ALL=${LANG}

# install python
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    python3 python3-pip python3-dev python3-setuptools python3-wheel python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --upgrade pip

# install docker
RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    apt-transport-https ca-certificates gnupg lsb-release \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends docker-ce docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker ${USERNAME}

# setup workspace directory
RUN mkdir /workspace \
    && chown -R ${USERNAME}:${USERNAME} /workspace
WORKDIR /workspace
