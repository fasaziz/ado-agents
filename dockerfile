FROM ubuntu:20.04

###### Could be worth looking into https://github.com/cruizba/ubuntu-dind if we have issues with below

ARG DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Install Python 3.9, requirements for python packages 
RUN apt-get update && apt-get install -y --no-install-recommends \
         wget gpg dirmngr gpg-agent build-essential checkinstall tk-dev \
         libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev \
         libgdbm-dev libc6-dev libbz2-dev ca-certificates libffi-dev uuid-dev lzma-dev liblzma-dev \
         gcc python3.9-dev python3-pip libxml2-dev libxslt1-dev zlib1g-dev g++ \
         python3.9 \
#    && wget https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz \
#    && tar xzf Python-3.9.7.tgz \
#    && cd /Python-3.9.7 \
#    && ./configure --enable-optimizations \
#    && make -j 8 \
#    && make install \
#    && cd .. \
#    && rm -rf Python-3.9.7.tgz /Python-3.9.7/ \
#    && apt-get remove -y build-essential checkinstall \
#    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 \
      && update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1

# Install and packages for Azure stuff 

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb && dpkg -i packages-microsoft-prod.deb

RUN apt-get update && apt-get install -y   --no-install-recommends \         
      curl jq git iputils-ping libcurl4 libunwind8 netcat libssl1.0 openssh-client \
      lxc iptables apt-transport-https dotnet-runtime-3.1 powershell \
      && apt autoremove -y \
      && rm -rf /var/lib/apt/lists/*

# Install Azure build build tasks
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
  && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.185.1

WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
    else \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
    fi; \
    curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz

# Setup DinD
RUN curl -sSL https://get.docker.com/ | sh

# Create user and group
RUN \
	addgroup --shell dockremap; \
	adduser --shell --group dockremap dockremap; \
	echo 'dockremap:165536:65536' >> /etc/subuid; \
	echo 'dockremap:165536:65536' >> /etc/subgid


# Setup modprobe
#ENV DOCKER_TLS_CERTDIR=/certs
#R#UN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
COPY scripts/modprobe.sh /usr/local/bin/modprobe

COPY scripts/dind /usr/local/bin/dind 
RUN chmod +x /usr/local/bin/dind

COPY scripts/dockerd-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/dockerd-entrypoint.sh

VOLUME /var/lib/docker
EXPOSE 2375 2376

# Setup start script for ADO
COPY scripts/start.sh .
RUN chmod +x start.sh
RUN sed -i -e 's/\r$//' start.sh

ENTRYPOINT "./start.sh" & "/usr/local/bin/dockerd-entrypoint.sh"