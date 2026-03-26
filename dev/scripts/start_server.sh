#!/bin/bash
export PATH="/Users/pv/.asdf/installs/elixir/1.18.4/bin:/Users/pv/.asdf/installs/erlang/28.3.1/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export MIX_ENV=dev
export HOME=/Users/pv

cd /Users/pv/Desktop/Claude/hub
exec mix phx.server
