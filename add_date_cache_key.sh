cd ~/jdcs/claude2/depict

# Update the cache keys to include rust version
sed -i 's/cargo-registry-\${{ hashFiles/cargo-registry-rust-2024-12-01-${{ hashFiles/' .github/workflows/1.12_test_build_depict.yml
sed -i 's/cargo-registry-$/cargo-registry-rust-2024-12-01-/' .github/workflows/1.12_test_build_depict_wf.yml

sed -i 's/cargo-git-\${{ hashFiles/cargo-git-rust-2024-12-01-${{ hashFiles/' .github/workflows/1.12_test_build_depict_wf.yml
sed -i 's/cargo-git-$/cargo-git-rust-2024-12-01-/' .github/workflows/1.12_test_build_depict_wf.yml

sed -i 's/cargo-build-\${{ hashFiles/cargo-build-rust-2024-12-01-${{ hashFiles/' .github/workflows/1.12_test_build_depict_wf.yml
sed -i 's/cargo-build-$/cargo-build-rust-2024-12-01-/' .github/workflows/1.12_test_build_depict_wf.yml

# Verify
grep "cache-key" .github/workflows/1.12_test_build_depict_wf.yml || grep "cargo-registry-rust" .github/workflows/1.12_test_build_depict_wf.yml

# Commit and push
#git add .github/workflows/build-depict.yml
#git commit -m "Bust cache to force fresh dependencies with nightly-2024-12-01"
#git push
