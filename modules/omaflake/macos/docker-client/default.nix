# SPDX-License-Identifier: MIT
# Module: docker-client (macOS) – the docker command, Compose and Buildx, for the Docker engine of another VM (module docker).
#
# The engine is reached on this VM's localhost: omaflake's ports of other VMs (omaflake plan B180) put port 2375 of the
# Docker VM there – in the app the VM's "Ports of other VMs", or `omaf set <this VM> --forwards 2375=<docker VM>`; both
# VMs must be in one omaflake network. Bind mounts name paths on the Docker VM: give both VMs the same volume under the
# same name, then /Volumes/<name>/… is the same path in both (omaflake plan B187).
#
# DOCKER_HOST reaches shells, not apps started from the Finder or the Dock (an editor's Docker integration): nix-darwin's
# launchd.user.envVariables sets it with `launchctl setenv` while the system is activated – at a VM's start that is
# before anyone logs in, and the value is gone (checked in a macOS 27 guest); a launch agent would bring a background
# item notice at every start (omaflake plan BM25). OPEN.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.docker-client pkgs.docker-compose pkgs.docker-buildx ];
  environment.variables.DOCKER_HOST = "tcp://127.0.0.1:2375";
}
