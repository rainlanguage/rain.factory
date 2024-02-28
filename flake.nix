{
  description = "Flake for development workflows.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rainix.url = "github:rainprotocol/rainix";
  };

  outputs = {self, rainix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = rainix.pkgs.${system};
      in rec {
        packages = rec {
          factory-prelude = pkgs.writeShellScriptBin "factory-prelude" ''
            forge build --force && \
            rain meta build \
              -o meta/CloneFactory.rain.meta \
              -i <(rain meta solc artifact -c abi -i out/CloneFactory.sol/CloneFactory.json) \
              -m solidity-abi-v2 \
              -t json \
              -e deflate \
              -l en
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = [ packages.factory-prelude ];
          inputsFrom = [ rainix.devShells.${system}.default ];
        };
      }
    );

}