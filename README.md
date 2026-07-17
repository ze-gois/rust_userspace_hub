# rust_userspace

```
sudo pacman -S git
```


``` need cc and ld by path ```

i often:

```
pacman -S gcc llvm
```


```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
git clone https://github.com/ze-gois/rust_userspace_hub
cd rust_userspace_hub
git submodule update --init --recursive
cargo run
```
