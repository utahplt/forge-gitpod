# Adapted from Dockerfile for `leanprovercommunity/mathlib:gitpod`.

FROM ubuntu:jammy

USER root

RUN apt-get update && apt-get install sudo git curl git bash-completion python3 python3-pip racket default-jdk default-jre -y && apt-get clean

RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
USER gitpod
WORKDIR /home/gitpod

SHELL ["/bin/bash", "-c"]

# gitpod bash prompt
RUN { echo && echo "PS1='\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$(__git_ps1 \" (%s)\") $ '" ; } >> .bashrc

# fix the infoview when the container is used on gitpod:
ENV VSCODE_API_VERSION="1.50.0"

# ssh to github once to bypass the unknown fingerprint warning
RUN ssh -o StrictHostKeyChecking=no github.com || true

RUN raco pkg install ./src/forge/forge ./src/forge/froglet ./src/asn1-lib/ ./src/base64-lib/ ./src/basedir/ ./src/beautiful-racket-demo/ ./src/beautiful-racket-lib/ ./src/beautiful-racket-macro/ ./src/beautiful-racket/ ./src/binaryio-lib/ ./src/br-parser-tools-doc/ ./src/br-parser-tools-lib/ ./src/brag-lib/ ./src/brag/ ./src/crypto-lib/ ./src/debug/ ./src/fancy-app/ ./src/gmp-lib/ ./src/mischief/ ./src/predicates/ ./src/pretty-format/ ./src/request/ ./src/scramble-lib/ ./src/sha/ ./src/sugar/ ./src/syntax-classes-doc/ ./src/syntax-classes-lib/ ./src/syntax-classes/

# run sudo once to suppress usage info
RUN sudo echo finished
