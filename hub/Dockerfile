FROM python:3.11

# Install WireGuard tools
RUN apt-get update && \
    apt-get install -y wireguard-tools iproute2 netcat-openbsd iputils-ping curl git apache2 cron && \
    rm -rf /var/lib/apt/lists/* 

# Set the working directory
WORKDIR /app

# Set up proxy server
RUN git clone https://github.com/Chewt/ollama_proxy_server.git
WORKDIR ollama_proxy_server
RUN pip3 install -e .

# Copy everything from the current directory into the container
COPY accept_new_peers.sh /app
COPY build_wg_config.sh /app
COPY find_next_ip.sh /app
COPY base_config.txt /app
COPY rebuild_and_start_wg.sh /app
COPY startup.sh /app
COPY build_proxy_conf.sh /app
COPY authorized_users.txt /app
COPY prune_old_peers.sh /app

# Default command
WORKDIR /app
ENTRYPOINT ["/app/startup.sh"]
