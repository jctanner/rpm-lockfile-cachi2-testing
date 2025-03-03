```sh
git clone https://github.com/konflux-ci/rpm-lockfile-prototype
cd rpm-lockfile-prototype
podman build -t jtanner/lockfile-prototype-test:latest -f Containerfile .
```

```sh
git clone https://github.com/jctanner/cachi2@ALLOW_SELF_SIGNED_CERTS_FLAG
cd cachi2
podman build -t jctanner/cachi2:latest .
```

```sh
./build_and_test.sh
```
