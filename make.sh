rust-objcopy --strip-all target/riscv64gc-unknown-none-elf/release/lib_os -O binary target/riscv64gc-unknown-none-elf/release/lib_os.bin
cargo build --release
