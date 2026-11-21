# RVMM NoMount

> [!NOTE]
> This is j-hc's RVMM rewritten to utilize NoMount \
> Magisk is **NOT** supported as NoMount only support KernelSU and APatch

> [!IMPORTANT]
> **This project is NOT provided by / related to original author repo.** \
> DO **NOT** REPORT ISSUES TO ORIGINAL AUTHOR

- Get the [latest CI release here](https://github.com/nleloc/rvmm-nm-build/releases)

- If you want, use [HMA-OSS](https://github.com/frknkrc44/HMA-OSS) to hide apps from Play Store to prevent update

<details><summary><big>Features</big></summary>
<ul>
 <li> Supports all present and future ReVanced apps (including projects implementing the same interface like Morphe)</li>
 <li> Receives in-app updates</li>
 <li> Can build modules and non-root APKs</li>
 <li> Updated daily with the latest versions of apps and patches</li>
 <li> Optimizes APKs and modules for size</li>
 <li> Modules</li>
    <ul>
     <li> handle installation of the correct version of the stock app and all that</li>
     <li> do not trigger root detections</li>
     <li> receive updates from KernelSU/AP app</li>
     <li> recompile invalidated odex for faster usage</li>
    </ul>
</ul>
</details>

## To include/exclude patches or patch other apps

 * Star the [original repo](https://github.com/j-hc/revanced-magisk-module) :eyes:
 * Fork this repo
 * Customize [`config.toml`](./config.toml) using [rvmm-config-gen](https://j-hc.github.io/rvmm-config-gen/)
 * Run the build [workflow](../../actions/workflows/build.yml)
 * Grab your modules and APKs from [releases](../../releases)

also see [`CONFIG.md`](./CONFIG.md)

## Building Locally
### On Linux
```console
$ git clone https://github.com/nleloc/rvmm-nm-build --depth 1
$ cd rvmm-nm-build
$ ./build.sh
```

## DISCLAIMER
> [!IMPORTANT]
> I'm not responsible for anything that can happen on your device by using this module. \
> Including bricked device, data loss or accidentally trigger a thermonuclear war.

## CREDITS
- [NoMount](https://github.com/maxsteeel/nomount): Provide in-kernel VFS file redirection without mounting
- [RVMM](https://github.com/j-hc/revanced-magisk-module): Original project
