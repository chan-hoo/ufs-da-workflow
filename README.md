# ufs-da-workflow
UFS DA (Data Assimilation) Workflow

## Quick Start Guide

1. Clone the `develop` branch of the authoritative repository:
```
git clone -b develop --recursive https://github.com/ufs-community/ufs-da-workflow
```

2. Move to the `sorc` directory:
```
cd ufs-da-workflow/sorc
```

3. Run the build script:
- Workflow components: YES, JEDI-bundle: NO
```
./app_build.sh
```

- Workflow components: YES, JEDI-bundle: YES
```
./app_build.sh --jedi=on
```

- Workflow components: NO, JEDI-bundle: YES
```
./app_build.sh --jedi=only
```
