use std::process::Command;

fn main() {
    let image = env!("CREAMOS_KERNEL_IMAGE");
    let status = Command::new("qemu-system-x86_64")
        .args(["-m", "512M", "-vga", "std", "-drive"])
        .arg(format!("file={image},format=raw"))
        .status()
        .expect("could not start qemu-system-x86_64; install QEMU first");

    if !status.success() {
        eprintln!("QEMU exited with status {status}");
        std::process::exit(status.code().unwrap_or(1));
    }
}
