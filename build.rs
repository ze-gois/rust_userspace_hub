use std::env;
use std::path::PathBuf;

fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // ======== Arquivo de linker ========
    let linker_script = PathBuf::from(&manifest_dir).join("linker.ld");
    println!("cargo:rerun-if-changed={}", linker_script.display());
    println!("cargo:rustc-link-arg=-T{}", linker_script.display());

    println!("cargo:rerun-if-changed=./build.rs");
    // println!("cargo:rerun-if-changed=./linker.ld");
    println!("cargo:rerun-if-changed=./src/");
    println!("cargo:rerun-if-changed=./crates/");

    // Static linking flags
    println!("cargo:rustc-link-arg=-static");
    println!("cargo:rustc-link-arg=--no-dynamic-linker");
    println!("cargo:rustc-link-arg=-n");

    // Disable position independent code
    println!("cargo:rustc-link-arg=--no-pie");

    // Compile assembly startup code
    cc::Build::new()
        .file("src/start.s")
        .flag("-fno-pic")
        .flag("-fno-pie")
        .compile("start");
}
