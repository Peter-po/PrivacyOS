# PrivacyOS

PrivacyOS 是一个基于 Android 开放源代码项目（AOSP）的隐私操作系统项目。目前处于开发引导阶段，包含安全设计、构建入口和设备安全基线测试。

## 开发目标

- 及时合入 Android 安全更新，维护可追踪的 AOSP 基线、下游补丁和设备支持周期。
- 保持应用沙箱、SELinux、设备加密和 Android Verified Boot 的安全属性，并为支持的设备验证这些属性。
- 将减少默认网络访问、限制应用访问敏感数据、提供可审计的系统更新作为待验证的开发方向。
- 以 GrapheneOS 等系统为参考，按设备、版本和场景公开可复核的比较结果。安全架构、威胁模型和首批验证范围见 [安全架构](docs/architecture.md)。

## 构建

在独立目录按 AOSP 官方说明安装主机依赖并同步一个明确的发行分支或标签。AOSP 建议至少预留 400 GB 磁盘空间和 64 GB 内存。设备目标与 `lunch` 语法以所选分支的文档为准。 [AOSP 构建环境](https://source.android.com/docs/setup/start/requirements) · [AOSP 构建指南](https://source.android.com/docs/setup/build/building)

以下示例使用支持三段式 `lunch` 的 AOSP 分支和 Cuttlefish 开发目标。当前脚本构建已同步的 AOSP 源码。PrivacyOS 专属系统改动、发行签名和发布流程仍在规划中。

```bash
./scripts/check_environment.sh /path/to/aosp
./scripts/build.sh /path/to/aosp aosp_cf_x86_64_only_phone-aosp_current-userdebug
```

构建脚本可选第三个参数指定并行任务数。使用 `--help` 查看两个脚本的参数。

## 测试

主机测试只需要 Bash、Git 和 Python 3，覆盖构建入口及设备检查脚本的成功与失败路径。

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

在隔离测试环境中，将目标 `user` 镜像启动到受支持的设备，并授权该设备的 ADB 测试会话。以下命令只读检查 SELinux、系统构建属性和启动验证状态，并对失败返回非零退出码。

```bash
adb devices
./tests/device_security_baseline.sh DEVICE_SERIAL
```

默认要求绿色 Verified Boot 状态。对已明确配置自定义信任根的测试设备，可传入 `--allow-custom-root` 接受黄色状态。设备属性检查适用于支持相应属性与 ADB 的设备，结果只反映这些属性和 SELinux 的运行时状态。安全发布仍需独立验证启动信任链和密钥管理。

## 许可证

本仓库以 [Apache License 2.0](LICENSE) 授权。AOSP 及第三方组件遵循各自的许可证。
