{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  version = "1.27.0";
  sources = {
    x86_64-linux = {
      arch = "linux_amd64";
      hash = "sha256-9/gm5SEU4+cYVbWA21aeGJHYzWkoAPcm4B4MosaK2LQ=";
    };
    aarch64-linux = {
      arch = "linux_arm64";
      hash = "sha256-s9dj6P1HXFIsFJ8pu4wjBrEcyh2uxNCTWm+Ra0vTrSE=";
    };
    x86_64-darwin = {
      arch = "darwin_amd64";
      hash = "sha256-GWiuxJaowqyIuNUT5iJiBCtUqrZS5Cma5XB2z3SFjsw=";
    };
    aarch64-darwin = {
      arch = "darwin_arm64";
      hash = "sha256-U1nEoSs5gxSNXlXoJg8MXD0ChdrWXsTv6SQQ0+/l7CU=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "inngest-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/inngest/inngest/releases/download/v${version}/inngest_${version}_${source.arch}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 inngest "$out/bin/inngest"
    ln -s "$out/bin/inngest" "$out/bin/inngest-cli"

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/inngest/inngest";
    description = "Inngest CLI";
    license = lib.licenses.unfreeRedistributable;
    platforms = builtins.attrNames sources;
  };
}
