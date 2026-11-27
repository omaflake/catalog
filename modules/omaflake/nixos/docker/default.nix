# SPDX-License-Identifier: MIT
# Module: docker – the Docker engine and Compose. The guest user runs docker without sudo.
#
# For other VMs (omaflake's networks between VMs, omaflake spec §11.12): the engine also listens on TCP port 2375, so a
# VM in the same network uses it – with the module docker-client and the port forward 2375=<this VM> as
# DOCKER_HOST=tcp://127.0.0.1:2375, or directly at tcp://<this VM's address>:2375 (`omaf networks show`). That port has
# no TLS and no login – every VM in this VM's networks is root here; the VM's own NAT does not let anything in, so
# nothing outside omaflake's networks reaches it.
#
# Bind mounts name paths on this VM. omaflake mounts a volume at /Volumes/<name> in every guest (omaflake plan B187),
# so `docker run -v "$PWD":/app` from another VM works when both have the volume under the same name.
{ pkgs, settings, ... }:

{
  virtualisation.docker = {
    enable = true;
    # Socket activation (nixpkgs' docker.socket): the local socket and TCP for the networks' other VMs
    listenOptions = [ "/run/docker.sock" "0.0.0.0:2375" ];
  };
  environment.systemPackages = [ pkgs.docker-compose ];
  users.users.${settings.user}.extraGroups = [ "docker" ];
  networking.firewall.allowedTCPPorts = [ 2375 ];
}
