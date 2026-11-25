# SPDX-License-Identifier: MIT
# Module: docker – the Docker engine and Compose. The guest user runs docker without sudo.
#
# For other VMs (omaflake's networks between VMs, omaflake spec §11.12): the engine also listens on TCP port 2375, so a
# macOS VM in the same network uses it with DOCKER_HOST=tcp://<this VM's address>:2375 (`omaf networks show`). That
# port has no TLS and no login – every VM in this VM's networks is root here; the VM's own NAT does not let anything
# in, so nothing outside omaflake's networks reaches it.
#
# Bind mounts name paths on this VM. A macOS VM's share folder is /Volumes/My Shared Files, this VM's is /mnt/share:
# the first is a link to the second, so `docker run -v "$PWD":/app` from the macOS VM works when both VMs share the
# same folder of the host.
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

  systemd.tmpfiles.rules = [
    "d /Volumes 0755 root root -"
    "L+ \"/Volumes/My Shared Files\" - - - - /mnt/share"
  ];
}
