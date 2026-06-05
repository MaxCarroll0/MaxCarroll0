{
  description = "Dev shell + runner for the README language-stats generator (Lua + tokei).";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = pkgs:
        let
          # What `nix run .` needs at runtime; deliberately excludes the LSP and formatters.
          runtimeDeps = [ pkgs.lua5_4 pkgs.tokei pkgs.yq-go pkgs.git pkgs.gh pkgs.coreutils ];

          luarc = (pkgs.formats.json { }).generate "luarc.json" {
            "runtime.version" = "Lua 5.4";
            "runtime.path" = [ "scripts/?.lua" "?.lua" ];
            "workspace.checkThirdParty" = false;
            "diagnostics.globals" = [ "arg" ];
          };
          # LSP config lives in the flake: wrap the server so it always loads the generated luarc.
          lua-ls = pkgs.writeShellScriptBin "lua-language-server" ''
            exec ${pkgs.lua-language-server}/bin/lua-language-server --configpath=${luarc} "$@"
          '';
        in
        {
          package = pkgs.writeShellApplication {
            name = "readme-stats";
            runtimeInputs = runtimeDeps;
            text = ''exec lua scripts/stats.lua "$@"'';
          };

          shell = pkgs.mkShell {
            packages = runtimeDeps ++ [
              # nixpkgs names the binary `lua`; expose `lua5.4` too so commands match CI.
              (pkgs.writeShellScriptBin "lua5.4" ''exec ${pkgs.lua5_4}/bin/lua "$@"'')
              lua-ls
              pkgs.stylua
              pkgs.taplo
            ];
          };
        };

      bySystem = nixpkgs.lib.genAttrs systems (s: perSystem nixpkgs.legacyPackages.${s});
    in
    {
      packages = nixpkgs.lib.mapAttrs (_: v: { default = v.package; }) bySystem;
      devShells = nixpkgs.lib.mapAttrs (_: v: { default = v.shell; }) bySystem;
    };
}
