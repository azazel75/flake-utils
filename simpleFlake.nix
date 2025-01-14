{ lib
, defaultSystems ? [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
}:
# This function returns a flake outputs-compatible schema.
{
  # pass an instance of self
  self
, # pass an instance of the nixpkgs flake
  nixpkgs
, # we assume that the name maps to the project name, and also that the
  # overlay has an attribute with the `name` prefix that contains all of the
  # project's packages.
  name
, # nixpkgs config
  config ? { }
, # pass either a function or a file
  overlay ? null
, # use this to load other flakes overlays to supplement nixpkgs
  preOverlays ? [ ]
, # maps to the devShell output. Pass in a shell.nix file or function.
  shell ? null
, # pass the list of supported systems
  systems ? defaultSystems
}:
let
  loadOverlay = obj:
    if obj == null then
      [ ]
    else
      [ (maybeImport obj) ]
  ;

  maybeImport = obj:
    if (builtins.typeOf obj == "path") || (builtins.typeOf obj == "string") then
      import obj
    else
      obj
  ;

  overlays = preOverlays ++ (loadOverlay overlay);

  shell_ = maybeImport shell;

  systemOutputs = lib.eachSystem systems (system:
    let
      pkgs = import nixpkgs {
        inherit
          config
          overlays
          system
          ;
      };
      inherit (pkgs.lib) composeManyExtensions filterAttrs;
      inherit (builtins) all;

      prePackages = pkgs.${name} or { };
    in
    {
      packages = filterAttrs (k: v: all (e: e != k)
        [ "apps" "checks" "devShells" ])
        prePackages;
    }
    //
    (
      if prePackages ? checks then {
        checks = prePackages.checks;
      } else { }
    )
    //
    (
      if shell != null then {
        devShells.default = shell_ { inherit pkgs; };
      } else if prePackages ? devShells then {
        devShells = prePackages.devShells;
      } else { }
    )
    //
    (
      if prePackages ? apps then {
        apps = prePackages.apps;
      } else { }
    )
  );
  outOverlays = {
    default = overlay;
    all = overlays;
    pre = preOverlays;
    composed = nixpkgs.lib.composeManyExtensions overlays;
  };
in
(systemOutputs // { overlays = outOverlays; })
