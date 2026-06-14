#!/bin/bash

set -e

echo "==> Installing dev tools..."
apt update -q
apt install -y cmake ninja-build git tig python3-pip clang-format bear

echo "==> Installing Python tools..."
pip3 install lit pytest numpy

if ! -d rocm-playground; then
    echo "==> Cloning your repos..."
    git clone https://github.com/mille-printemps/rocm-playground.git
fi

git config --global alias.ss "status"
git config --global alias.br "branch"
git config --global alias.brm "branch -m"
git config --global alias.brd "branch -d"
git config --global alias.brdd "branch -D"
git config --global alias.co "checkout"
git config --global alias.cob "checkout -b"
git config --global alias.adu "add -u"
git config --global alias.adup "add -u -p"
git config --global alias.comm "commit -m"
git config --global alias.mg "merge --no-ff"
git config --global alias.mgff "merge --ff"
git config --global alias.cp "cherry-pick"
git config --global alias.log1 "log -1"
git config --global alias.log2 "log -2"
git config --global alias.log3 "log -3"
git config --global alias.logo "log --oneline"
git config --global alias.logn "log --name-status --oneline"
git config --global alias.logg "log --graph --all --decorate"

echo ""
echo "✓ Ready."
