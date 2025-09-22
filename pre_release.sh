#!/usr/bin/sh
echo "pre"

cp ./crates/userspace_build/Cargo.toml ./crates/userspace_build/Cargo.toml.tmp
cp ./crates/userspace_build/build.rs ./crates/userspace_build/build.rs.tmp
cp ./crates/userspace_build/pre_release.sh ./crates/userspace_build/pre_release.sh.tmp
cp ./crates/userspace_build/pos_release.sh ./crates/userspace_build/pos_release.sh.tmp

cp -r ./crates/userspace/* ./crates/userspace_build
cp -r ./crates/userspace/.cargo ./crates/userspace_build/.cargo

rg -l 'userspace' ./crates/userspace_build/**/*.rs | xargs sed -i 's/userspace/userspace_build/g'

mv ./crates/userspace_build/Cargo.toml.tmp ./crates/userspace_build/Cargo.toml
mv ./crates/userspace_build/build.rs.tmp ./crates/userspace_build/build.rs
mv ./crates/userspace_build/pos_release.sh.tmp ./crates/userspace_build/pos_release.sh
mv ./crates/userspace_build/pre_release.sh.tmp ./crates/userspace_build/pre_release.sh

./scripts/submodules/push_to_branch.sh release --auto
