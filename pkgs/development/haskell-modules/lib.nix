# TODO(@Ericson2314): Remove `pkgs` param, which is only used for
# `buildStackProject`, `justStaticExecutables` and `checkUnusedPackages`
{ pkgs, lib }:

rec {
  /* This function takes a file like `hackage-packages.nix` and constructs
     a full package set out of that.
   */
  makePackageSet = import ./make-package-set.nix;

  /* The function overrideCabal lets you alter the arguments to the
     mkDerivation function.

     Example:

     First, note how the aeson package is constructed in hackage-packages.nix:

         "aeson" = callPackage ({ mkDerivation, attoparsec, <snip>
                                }:
                                  mkDerivation {
                                    pname = "aeson";
                                    <snip>
                                    homepage = "https://github.com/bos/aeson";
                                  })

     The mkDerivation function of haskellPackages will take care of putting
     the homepage in the right place, in meta.

         > haskellPackages.aeson.meta.homepage
         "https://github.com/bos/aeson"

         > x = haskell.lib.overrideCabal haskellPackages.aeson (old: { homepage = old.homepage + "#readme"; })
         > x.meta.homepage
         "https://github.com/bos/aeson#readme"

   */
  overrideCabal = drv: f: (drv.override (args: args // {
    mkDerivation = drv: (args.mkDerivation drv).override f;
  })) // {
    overrideScope = scope: overrideCabal (drv.overrideScope scope) f;
  };

  # : Map Name (Either Path VersionNumber) -> HaskellPackageOverrideSet
  # Given a set whose values are either paths or version strings, produces
  # a package override set (i.e. (self: super: { etc. })) that sets
  # the packages named in the input set to the corresponding versions
  packageSourceOverrides =
    overrides: self: super: pkgs.lib.mapAttrs (name: src:
      let isPath = x: builtins.substring 0 1 (toString x) == "/";
          generateExprs = if isPath src
                             then self.callCabal2nix
                             else self.callHackage;
      in generateExprs name src {}) overrides;

  /* doCoverage modifies a haskell package to enable the generation
     and installation of a coverage report.

     See https://wiki.haskell.org/Haskell_program_coverage
   */
  doCoverage = drv: overrideCabal drv (drv: { doCoverage = true; });

  /* dontCoverage modifies a haskell package to disable the generation
     and installation of a coverage report.
   */
  dontCoverage = drv: overrideCabal drv (drv: { doCoverage = false; });

  /* doHaddock modifies a haskell package to enable the generation and
     installation of API documentation from code comments using the
     haddock tool.
   */
  doHaddock = drv: overrideCabal drv (drv: { doHaddock = true; });

  /* dontHaddock modifies a haskell package to disable the generation and
     installation of API documentation from code comments using the
     haddock tool.
   */
  dontHaddock = drv: overrideCabal drv (drv: { doHaddock = false; });

  /* doJailbreak enables the removal of version bounds from the cabal
     file. You may want to avoid this function.

     This is useful when a package reports that it can not be built
     due to version mismatches. In some cases, removing the version
     bounds entirely is an easy way to make a package build, but at
     the risk of breaking software in non-obvious ways now or in the
     future.

     Instead of jailbreaking, you can patch the cabal file.
   */
  doJailbreak = drv: overrideCabal drv (drv: { jailbreak = true; });

  /* dontJailbreak restores the use of the version bounds the check
     the use of dependencies in the package description.
   */
  dontJailbreak = drv: overrideCabal drv (drv: { jailbreak = false; });

  /* doCheck enables dependency checking, compilation and execution
     of test suites listed in the package description file.
   */
  doCheck = drv: overrideCabal drv (drv: { doCheck = true; });
  /* dontCheck disables dependency checking, compilation and execution
     of test suites listed in the package description file.
   */
  dontCheck = drv: overrideCabal drv (drv: { doCheck = false; });

  /* doBenchmark enables dependency checking, compilation and execution
     for benchmarks listed in the package description file.
   */
  doBenchmark = drv: overrideCabal drv (drv: { doBenchmark = true; });
  /* dontBenchmark disables dependency checking, compilation and execution
     for benchmarks listed in the package description file.
   */
  dontBenchmark = drv: overrideCabal drv (drv: { doBenchmark = false; });

  /* doDistribute enables the distribution of binaries for the package
     via hydra.
   */
  doDistribute = drv: overrideCabal drv (drv: { hydraPlatforms = drv.platforms or ["i686-linux" "x86_64-linux" "x86_64-darwin"]; });
  /* dontDistribute disables the distribution of binaries for the package
     via hydra.
   */
  dontDistribute = drv: overrideCabal drv (drv: { hydraPlatforms = []; });

  /* appendConfigureFlag adds a single argument that will be passed to the
     cabal configure command, after the arguments that have been defined
     in the initial declaration or previous overrides.

     Example:

         > haskell.lib.appendConfigureFlag haskellPackages.servant "--profiling-detail=all-functions"
   */
  appendConfigureFlag = drv: x: overrideCabal drv (drv: { configureFlags = (drv.configureFlags or []) ++ [x]; });

  /* removeConfigureFlag drv x is a Haskell package like drv, but with
     all cabal configure arguments that are equal to x removed.

         > haskell.lib.removeConfigureFlag haskellPackages.servant "--verbose"
   */
  removeConfigureFlag = drv: x: overrideCabal drv (drv: { configureFlags = lib.remove x (drv.configureFlags or []); });

  addBuildTool = drv: x: addBuildTools drv [x];
  addBuildTools = drv: xs: overrideCabal drv (drv: { buildTools = (drv.buildTools or []) ++ xs; });

  addExtraLibrary = drv: x: addExtraLibraries drv [x];
  addExtraLibraries = drv: xs: overrideCabal drv (drv: { extraLibraries = (drv.extraLibraries or []) ++ xs; });

  addBuildDepend = drv: x: addBuildDepends drv [x];
  addBuildDepends = drv: xs: overrideCabal drv (drv: { buildDepends = (drv.buildDepends or []) ++ xs; });

  addPkgconfigDepend = drv: x: addPkgconfigDepends drv [x];
  addPkgconfigDepends = drv: xs: overrideCabal drv (drv: { pkgconfigDepends = (drv.pkgconfigDepends or []) ++ xs; });

  addSetupDepend = drv: x: addSetupDepends drv [x];
  addSetupDepends = drv: xs: overrideCabal drv (drv: { setupHaskellDepends = (drv.setupHaskellDepends or []) ++ xs; });

  enableCabalFlag = drv: x: appendConfigureFlag (removeConfigureFlag drv "-f-${x}") "-f${x}";
  disableCabalFlag = drv: x: appendConfigureFlag (removeConfigureFlag drv "-f${x}") "-f-${x}";

  markBroken = drv: overrideCabal drv (drv: { broken = true; hydraPlatforms = []; });
  markBrokenVersion = version: drv: assert drv.version == version; markBroken drv;

  enableLibraryProfiling = drv: overrideCabal drv (drv: { enableLibraryProfiling = true; });
  disableLibraryProfiling = drv: overrideCabal drv (drv: { enableLibraryProfiling = false; });

  enableSharedExecutables = drv: overrideCabal drv (drv: { enableSharedExecutables = true; });
  disableSharedExecutables = drv: overrideCabal drv (drv: { enableSharedExecutables = false; });

  enableSharedLibraries = drv: overrideCabal drv (drv: { enableSharedLibraries = true; });
  disableSharedLibraries = drv: overrideCabal drv (drv: { enableSharedLibraries = false; });

  enableDeadCodeElimination = drv: overrideCabal drv (drv: { enableDeadCodeElimination = true; });
  disableDeadCodeElimination = drv: overrideCabal drv (drv: { enableDeadCodeElimination = false; });

  enableStaticLibraries = drv: overrideCabal drv (drv: { enableStaticLibraries = true; });
  disableStaticLibraries = drv: overrideCabal drv (drv: { enableStaticLibraries = false; });

  appendPatch = drv: x: appendPatches drv [x];
  appendPatches = drv: xs: overrideCabal drv (drv: { patches = (drv.patches or []) ++ xs; });

  doHyperlinkSource = drv: overrideCabal drv (drv: { hyperlinkSource = true; });
  dontHyperlinkSource = drv: overrideCabal drv (drv: { hyperlinkSource = false; });

  disableHardening = drv: flags: overrideCabal drv (drv: { hardeningDisable = flags; });

  /* Let Nix strip the binary files.
   * This removes debugging symbols.
   */
  doStrip = drv: overrideCabal drv (drv: { dontStrip = false; });

  /* Stop Nix from stripping the binary files.
   * This keeps debugging symbols.
   */
  dontStrip = drv: overrideCabal drv (drv: { dontStrip = true; });

  /* Useful for debugging segfaults with gdb.
   * This includes dontStrip.
   */
  enableDWARFDebugging = drv:
   # -g: enables debugging symbols
   # --disable-*-stripping: tell GHC not to strip resulting binaries
   # dontStrip: see above
   appendConfigureFlag (dontStrip drv) "--ghc-options=-g --disable-executable-stripping --disable-library-stripping";

  /* Create a source distribution tarball like those found on hackage,
     instead of building the package.
   */
  sdistTarball = pkg: lib.overrideDerivation pkg (drv: {
    name = "${drv.pname}-source-${drv.version}";
    # Since we disable the haddock phase, we also need to override the
    # outputs since the separate doc output will not be produced.
    outputs = ["out"];
    buildPhase = "./Setup sdist";
    haddockPhase = ":";
    checkPhase = ":";
    installPhase = "install -D dist/${drv.pname}-*.tar.gz $out/${drv.pname}-${drv.version}.tar.gz";
    fixupPhase = ":";
  });

  /* Use the gold linker. It is a linker for ELF that is designed
     "to run as fast as possible on modern systems"
   */
  linkWithGold = drv : appendConfigureFlag drv
    "--ghc-option=-optl-fuse-ld=gold --ld-option=-fuse-ld=gold --with-ld=ld.gold";

  /* link executables statically against haskell libs to reduce
     closure size
   */
  justStaticExecutables = drv: overrideCabal drv (drv: {
    enableSharedExecutables = false;
    isLibrary = false;
    doHaddock = false;
    postFixup = "rm -rf $out/lib $out/nix-support $out/share/doc";
  } // lib.optionalAttrs (pkgs.hostPlatform.isDarwin) {
    configureFlags = (drv.configureFlags or []) ++ ["--ghc-option=-optl=-dead_strip"];
  });

  /* Build a source distribution tarball instead of using the source files
     directly. The effect is that the package is built as if it were published
     on hackage. This can be used as a test for the source distribution,
     assuming the build fails when packaging mistakes are in the cabal file.
   */
  buildFromSdist = pkg: lib.overrideDerivation pkg (drv: {
    unpackPhase = let src = sdistTarball pkg; tarname = "${pkg.pname}-${pkg.version}"; in ''
      echo "Source tarball is at ${src}/${tarname}.tar.gz"
      tar xf ${src}/${tarname}.tar.gz
      cd ${pkg.pname}-*
    '';
  });

  /* Build the package in a strict way to uncover potential problems.
     This includes buildFromSdist and failOnAllWarnings.
   */
  buildStrictly = pkg: buildFromSdist (failOnAllWarnings pkg);

  /* Turn on most of the compiler warnings and fail the build if any
     of them occur. */
  failOnAllWarnings = drv: appendConfigureFlag drv "--ghc-option=-Wall --ghc-option=-Werror";

  /* Add a post-build check to verify that dependencies declared in
     the cabal file are actually used.

     The first attrset argument can be used to configure the strictness
     of this check and a list of ignored package names that would otherwise 
     cause false alarms.
   */
  checkUnusedPackages =
    { ignoreEmptyImports ? false
    , ignoreMainModule   ? false
    , ignorePackages     ? []
    } : drv :
      overrideCabal (appendConfigureFlag drv "--ghc-option=-ddump-minimal-imports") (_drv: {
        postBuild = with lib;
          let args = concatStringsSep " " (
                       optional ignoreEmptyImports "--ignore-empty-imports" ++
                       optional ignoreMainModule   "--ignore-main-module" ++
                       map (pkg: "--ignore-package ${pkg}") ignorePackages
                     );
          in "${pkgs.haskellPackages.packunused}/bin/packunused" +
             optionalString (args != "") " ${args}";
      });

  buildStackProject = pkgs.callPackage ./generic-stack-builder.nix { };

  /* Add a dummy command to trigger a build despite an equivalent
     earlier build that is present in the store or cache.
   */
  triggerRebuild = drv: i: overrideCabal drv (drv: { postUnpack = ": trigger rebuild ${toString i}"; });

  /* Override the sources for the package and optionaly the version.
     This also takes of removing editedCabalFile.
   */
  overrideSrc = drv: { src, version ? drv.version }:
    overrideCabal drv (_: { inherit src version; editedCabalFile = null; });

  # Extract the haskell build inputs of a haskell package.
  # This is useful to build environments for developing on that
  # package.
  getHaskellBuildInputs = p:
    (p.override { mkDerivation = extractBuildInputs p.compiler;
                }).haskellBuildInputs;

  # Under normal evaluation, simply return the original package. Under
  # nix-shell evaluation, return a nix-shell optimized environment.
  shellAware = p: if lib.inNixShell then p.env else p;

  ghcInfo = ghc:
    rec { isCross = (ghc.cross or null) != null;
          isGhcjs = ghc.isGhcjs or false;
          nativeGhc = if isCross || isGhcjs
                        then ghc.bootPkgs.ghc
                        else ghc;
        };

  ### mkDerivation helpers
  # These allow external users of a haskell package to extract
  # information about how it is built in the same way that the
  # generic haskell builder does, by reusing the same functions.
  # Each function here has the same interface as mkDerivation and thus
  # can be called for a given package simply by overriding the
  # mkDerivation argument it used. See getHaskellBuildInputs above for
  # an example of this.

  # Some information about which phases should be run.
  controlPhases = ghc: let inherit (ghcInfo ghc) isCross; in
                  { doCheck ? !isCross && (lib.versionOlder "7.4" ghc.version)
                  , doBenchmark ? false
                  , ...
                  }: { inherit doCheck doBenchmark; };

  # Divide the build inputs of the package into useful sets.
  extractBuildInputs = ghc:
    { setupHaskellDepends ? [], extraLibraries ? []
    , librarySystemDepends ? [], executableSystemDepends ? []
    , pkgconfigDepends ? [], libraryPkgconfigDepends ? []
    , executablePkgconfigDepends ? [], testPkgconfigDepends ? []
    , benchmarkPkgconfigDepends ? [], testDepends ? []
    , testHaskellDepends ? [], testSystemDepends ? []
    , testToolDepends ? [], benchmarkDepends ? []
    , benchmarkHaskellDepends ? [], benchmarkSystemDepends ? []
    , benchmarkToolDepends ? [], buildDepends ? []
    , libraryHaskellDepends ? [], executableHaskellDepends ? []
    , ...
    }@args:
    let inherit (ghcInfo ghc) isGhcjs nativeGhc;
        inherit (controlPhases ghc args) doCheck doBenchmark;
        isHaskellPkg = x: x ? isHaskellLibrary;
        allPkgconfigDepends =
          pkgconfigDepends ++ libraryPkgconfigDepends ++
          executablePkgconfigDepends ++
          lib.optionals doCheck testPkgconfigDepends ++
          lib.optionals doBenchmark benchmarkPkgconfigDepends;
        otherBuildInputs =
          setupHaskellDepends ++ extraLibraries ++
          librarySystemDepends ++ executableSystemDepends ++
          allPkgconfigDepends ++
          lib.optionals doCheck ( testDepends ++ testHaskellDepends ++
                                  testSystemDepends ++ testToolDepends
                                ) ++
          # ghcjs's hsc2hs calls out to the native hsc2hs
          lib.optional isGhcjs nativeGhc ++
          lib.optionals doBenchmark ( benchmarkDepends ++
                                      benchmarkHaskellDepends ++
                                      benchmarkSystemDepends ++
                                      benchmarkToolDepends
                                    );
        propagatedBuildInputs =
          buildDepends ++ libraryHaskellDepends ++
          executableHaskellDepends;
        allBuildInputs = propagatedBuildInputs ++ otherBuildInputs;
        isHaskellPartition =
          lib.partition isHaskellPkg allBuildInputs;
    in
      { haskellBuildInputs = isHaskellPartition.right;
        systemBuildInputs = isHaskellPartition.wrong;
        inherit propagatedBuildInputs otherBuildInputs
          allPkgconfigDepends;
      };

}
