FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    openssh-server \
    rsync \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd
RUN mkdir -p /root/.ssh

COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 2222

CMD ["/init.sh"]