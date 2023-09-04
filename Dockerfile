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

# setup and configure fish
RUN apt-add-repository ppa:fish-shell/release-3 \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends fish direnv \
    && chsh -s /usr/bin/fish ${USERNAME}

USER ${USERNAME}
RUN fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher \
    && fisher install IlanCosman/tide@v5 \
    && fisher install jhillyerd/plugin-git \
    && fisher install halostatue/fish-docker \
    && set -U fish_greeting "" \
    && set -U tide_cmd_duration_icon \uf252 \
    && set -U tide_git_icon \uf1d3 \
    && set -U tide_left_prompt_items os\x1epwd\x1egit\x1enewline\x1echaracter \
    && set -U tide_left_prompt_prefix \x1d \
    && set -U tide_os_icon \uf31b \
    && set -U tide_prompt_color_frame_and_connection 808080 \
    && set -U tide_prompt_icon_connection \u00b7 \
    && set -U tide_pwd_icon \uf07c \
    && set -U tide_pwd_icon_home \uf015 \
    && set -U tide_right_prompt_items status\x1ecmd_duration\x1econtext\x1ejobs\x1edirenv\x1enode\x1evirtual_env\x1erustc\x1ejava\x1ephp\x1epulumi\x1echruby\x1ego\x1egcloud\x1ekubectl\x1edistrobox\x1etoolbox\x1eterraform\x1eaws\x1enix_shell\x1ecrystal\x1eelixir\x1etime \
    && set -U tide_right_prompt_suffix \x1d \
    && echo 'alias tmux=\"tmux -u\"' >> /home/${USERNAME}/.config/fish/config.fish \
    && echo 'direnv hook fish | source' >> /home/${USERNAME}/.config/fish/config.fish"

# setup pyenv
ARG GLOBAL_PYTHON_VERSION=miniconda3-latest
RUN fish -c "git clone https://github.com/pyenv/pyenv.git /home/${USERNAME}/.pyenv \
    && fish_add_path /home/${USERNAME}/.pyenv/bin \ && set -Ux PYENV_ROOT /home/${USERNAME}/.pyenv \
    && cd /home/${USERNAME}/.pyenv && src/configure && make -C src \
    && echo 'pyenv init - | source' >> /home/${USERNAME}/.config/fish/config.fish \
    && pyenv install ${GLOBAL_PYTHON_VERSION} \
    && pyenv global ${GLOBAL_PYTHON_VERSION}"

# setup pipx
RUN fish -c "python3 -m pip install --user pipx \
    && python3 -m pipx ensurepath \
    && fish_add_path /home/${USERNAME}/.local/bin \
    && register-python-argcomplete --shell fish pipx > /home/${USERNAME}/.config/fish/completions/pipx.fish"

# install python development tools
RUN fish -c "pipx install black"
RUN fish -c "pipx install flake8"
RUN fish -c "pipx install isort"
RUN fish -c "pipx install mypy"
RUN fish -c "pipx install ruff"
RUN fish -c "pipx install pytest"
RUN fish -c "pipx install tox"
RUN fish -c "pipx install pre-commit"
RUN fish -c "pipx install awscli"
RUN fish -c "pipx install poetry \
    && poetry completions fish > /home/${USERNAME}/.config/fish/completions/poetry.fish"

# configure git
ARG GIT_USER_EMAIL
ARG GIT_USER_NAME
RUN echo "[user]\n\
	email = ${GIT_USER_EMAIL}\n\
	name = ${GIT_USER_NAME}\n\
[core]\n\
	excludesfile = /home/${USERNAME}/.gitignore_global\n\
	editor = vim\n\
[alias]\n\
	squash-all = \"!f(){ git reset \$(git commit-tree HEAD^{tree} -m \"${1:-Initial commit}\");};f\"\n\
[pull]\n\
	rebase = false\n\
[init]\n\
	defaultBranch = master\n\
[rebase]\n\
	autosquash = true\n\
	autostash = true\n\
[submodule]\n\
	recurse = true\n\
[push]\n\
	autoSetupRemote = true\n\
[filter \"lfs\"]\n\
	clean = git-lfs clean -- %f\n\
	smudge = git-lfs smudge -- %f\n\
	process = git-lfs filter-process\n\
	required = true" >> /home/${USERNAME}/.gitconfig
RUN echo ".envrc\n.direnv/" >> /home/${USERNAME}/.gitignore_global

# configure direnv
RUN echo "layout_poetry() {\n\
  if [[ ! -f pyproject.toml ]]; then\n\
    log_error 'No pyproject.toml found.  Use `poetry new` or `poetry init` to create one first.'\n\
    exit 2\n\
  fi\n\n\
  local VENV=$(dirname $(poetry run which python))\n\
  export VIRTUAL_ENV=$(echo \"\$VENV\" | rev | cut -d'/' -f2- | rev)\n\
  export POETRY_ACTIVE=1\n\
  PATH_add \"\$VENV\"\n\
}" >> /home/${USERNAME}/.direnvrc

# minor tweaks
RUN echo "filetype plugin indent on\nsyntax on" >> /home/${USERNAME}/.vimrc
RUN echo "set -g default-terminal \"screen-256color\"" > /home/${USERNAME}/.tmux.conf

USER root
