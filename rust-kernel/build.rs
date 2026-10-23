use std::{env, path::PathBuf};

fn main() {
    let kernel = PathBuf::from(
        env::var_os("CARGO_BIN_FILE_CREAM_KERNEL_cream-kernel")
            .expect("Cargo did not provide the bare-metal kernel artifact"),
    );
    let image = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo did not provide OUT_DIR"))
        .join("creamos-kernel.img");

    bootloader::BiosBoot::new(&kernel)
        .create_disk_image(&image)
        .expect("failed to create the bootable CreamOS kernel image");

    println!("cargo:rustc-env=CREAMOS_KERNEL_IMAGE={}", image.display());
}
