#!/usr/bin/zsh
DIR=$1
if [[ -z "$DIR" ]]; then
    DIR=$(pwd)
fi
for toml in $(find "$DIR" -type f -name "Cargo.toml"); do
    echo cargo clean --manifest-path=$toml
    cargo clean --manifest-path=$toml --verbose
done
