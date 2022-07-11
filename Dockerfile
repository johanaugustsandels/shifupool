FROM ubuntu:22.04
ENV PROMPT_COMMAND="history -a"
ENV PATH="/root/.asdf/shims/:/asdf/bin:${PATH}"

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  ca-certificates \
  curl nano wget git \
  build-essential meson \
  && apt-get clean

RUN git clone https://github.com/asdf-vm/asdf.git /asdf --branch v0.9.0 \
  && rm -rf /asdf/.git

WORKDIR /app

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  libssl-dev automake autoconf libncurses5-dev \
  && apt-get clean

RUN asdf plugin add erlang
RUN asdf install erlang 25.0.2 && asdf global erlang 25.0.2

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  unzip \
  && apt-get clean

RUN asdf plugin add elixir
RUN asdf install elixir 1.13.4 && asdf global elixir 1.13.4

WORKDIR /
COPY entrypoint.sh .
ENTRYPOINT [ "/entrypoint.sh" ]