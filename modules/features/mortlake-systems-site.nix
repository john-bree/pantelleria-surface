# mortlake.systems — company one-pager, served straight from the nix
# store (stateless: no data dirs, nothing to back up). The co-located
# mortlake-systems/ dir travels with this module. TLS is the DNS-01
# Porkbun cert from acme-wildcard.nix; DNS freshness is dd-client.nix.
{
  flake.nixosModules.mortlake-systems-site =
    { config, lib, ... }:
    {
      services.nginx.virtualHosts = lib.mkIf config.services.nginx.enable {
        "mortlake.systems" = {
          forceSSL = true;
          useACMEHost = "mortlake.systems";
          root = builtins.path { path = ./mortlake-systems-site; };
        };
        "www.mortlake.systems" = {
          forceSSL = true;
          useACMEHost = "mortlake.systems";
          globalRedirect = "mortlake.systems";
        };
      };
    };
}
