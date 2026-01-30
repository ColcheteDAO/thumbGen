FROM ubuntu:24.04
RUN apt-get update && apt-get install -y imagemagick git curl jq wget
SHELL ["/bin/bash", "-c"]
