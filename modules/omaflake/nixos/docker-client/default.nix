# SPDX-License-Identifier: MIT
# Module: docker-client (NixOS) – the docker command, Compose and Buildx, for the Docker engine of another VM (module docker).
#
# The engine is reached on this VM's localhost: omaflake's ports of other VMs (omaflake plan B180) put port 2375 of the
# Docker VM there – in the app the VM's "Ports of other VMs", or `omaf set <this VM> --forwards 2375=<docker VM>`; both
# VMs must be in one omaflake network. Bind mounts name paths on the Docker VM: give both VMs the same volume under the
# same name, then /Volumes/<name>/… is the same path in both (omaflake plan B187).
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.docker-client pkgs.docker-compose pkgs.docker-buildx ];
  environment.sessionVariables.DOCKER_HOST = "tcp://127.0.0.1:2375";
}
