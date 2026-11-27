# DDNS client — Porkbun. Only active subdomains.
let
  baseDomain = "otwell.dev";
  secrets-opts = {
    owner = "john";
    sopsFile = ./secrets.yaml;
  };
in
{
  flake.nixosModules.dd-client =
    { config, ... }:
    let
      p = config.sops.placeholder;
    in
    {
      sops.secrets = {
        "porkbun-api-key" = secrets-opts;
        "porkbun-secret-api-key" = secrets-opts;
      };

      sops.templates."porkbun-ddclient.conf" = {
        content = ''
          apikey=${p.porkbun-api-key}
          secretapikey=${p.porkbun-secret-api-key}
        '';
        mode = "0400";
        owner = "john";
      };

      services.ddclient = {
        enable = true;
        protocol = "porkbun";
        interval = "5min";
        # We are IPv4-only: the v6 default creates failure noise
        usev6 = "disabled";
        # Only names that carry public DNS records — tailnet-only names
        # are gone from public DNS (their TLS is the wildcard DNS-01
        # cert); ddclient would fail on them every run ("no applicable
        # existing records").
        #
        # The porkbun protocol splits a hostname at the FIRST dot
        # (sub.foo.example.com -> sub + foo.example.com), which mis-parses
        # a zone apex: mortlake.systems -> "mortlake" + "systems" (wrong
        # zone -> 400). root-domain=mortlake.systems names the real zone so
        # the apex maps to an empty subdomain and www to "www".
        #
        # root-domain MUST be inline on the mortlake host line, not on a
        # line of its own: a standalone assignment becomes a global, and
        # opt() falls back to globals for any host without a per-host
        # value, so the otwell.dev names would inherit it and fail
        # ("hostname does not end with root-domain"). Inline keeps it
        # per-host. extraConfig renders before `domains`, so the mortlake
        # block lives here and the default-split otwell.dev names below.
        extraConfig = ''
          # After a failed update ddclient gates retries on
          # min-error-interval (default 5m), which races the 5m timer and
          # wedges failing patterns; retry failures quickly instead.
          min-error-interval=30s
          root-domain=mortlake.systems,mortlake.systems,www.mortlake.systems
        '';
        # IMPERATIVE (one-time, done 2026-11-23): ddclient only edits
        # existing records — the mortlake.systems apex + www A records
        # were created via the Porkbun API (dns/create, ttl 600, home
        # WAN IP). The parking apex ALIAS and the wildcard CNAME
        # (*.mortlake.systems -> pixie.porkbun.com) were deleted first:
        # the ALIAS conflicts with an A record, and the wildcard CNAME
        # hijacks lego's DNS-01 _acme-challenge lookup (it follows the
        # CNAME to porkbun.com, a zone not in the account -> issuance
        # 400). Trigger: any new name added here needs its A record
        # created in Porkbun before ddclient can manage it.
        domains = [
          "ssh.${baseDomain}"
          "cache.${baseDomain}"
          "jehoel.${baseDomain}"
          "deletion.${baseDomain}"
        ];
        secretsFile = config.sops.templates."porkbun-ddclient.conf".path;
      };
    };
}
