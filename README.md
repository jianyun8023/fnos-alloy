# FNOS Alloy

Grafana Alloy for FNOS - 飞牛 OS 的可观测性数据收集器。

## 简介

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) 是 Grafana Labs 推出的开源 OpenTelemetry Collector 发行版。本项目将其打包为 FNOS 应用（FPK 格式），方便在飞牛 OS 上安装和运行。

主要功能：
- **日志收集**：自动收集系统日志、应用运行日志。
- **日志推送**：将收集到的日志发送到 Loki 服务（支持本地或远程 Loki，如 Grafana Cloud）。
- **多架构支持**：同时支持 x86 (amd64) 和 ARM (arm64) 架构。

## 安装指南

1. 下载对应架构的 `.fpk` 安装包：
   - x86/amd64: `grafana.alloy_x.x.x_x86.fpk`
   - ARM/arm64: `grafana.alloy_x.x.x_arm.fpk`
2. 登录 FNOS 管理后台。
3. 进入 **应用中心** -> **手动安装**。
4. 上传 `.fpk` 文件并按照向导完成安装。

## 配置说明

在安装过程中或安装后（如果是安装后修改配置，需卸载重装或手动修改配置文件），您可以通过向导配置以下参数：

### 1. Loki 服务配置
- **Loki Push URL**: Loki 服务的日志接收地址。
  - 默认值: `http://localhost:3100/loki/api/v1/push`
  - 如果使用 Grafana Cloud，请使用提供的 URL。
- **启用认证**: 如果 Loki 服务需要认证（如 Basic Auth），请开启此选项。
- **主机名**: 用于在 Loki 中标识当前设备（对应 `hostname` 标签），默认为 `fnos`。

### 2. 认证配置（可选）
如果启用了认证，需要填写：
- **用户名**: Basic Auth 用户名。
- **密码**: Basic Auth 密码或 API Token。
- **租户 ID**: 多租户模式下的 Tenant ID（可选）。

### 3. 自定义标签
您可以添加最多 3 组自定义标签（Key-Value），用于在 Grafana 中筛选日志，例如：
- `env=production`
- `location=home`

## 权限说明

为了能够收集系统日志，该应用需要以下权限：
- **运行身份**: `root`
- **只读路径**:
  - `/var/log`: 系统日志目录
  - `/run/log/journal`: systemd journal 日志
  - `/usr/trim/nginx/logs`: Nginx 日志

## 构建指南

如果您需要自己构建安装包，请遵循以下步骤：

### 依赖要求
- Linux 或 macOS 环境
- `curl`
- `unzip`
- `fnpack` (构建脚本会自动下载)

### 构建命令

在项目根目录下运行 `build.sh` 脚本：

```bash
# 构建所有架构 (x86 和 arm)
./build.sh all

# 仅构建 x86
./build.sh amd64

# 仅构建 arm
./build.sh arm64

# 清理构建缓存
./build.sh clean
```

构建完成后，`.fpk` 文件将生成在项目根目录。

## 目录结构

- `app/`: 包含运行时所需的二进制文件和资源。
- `cmd/`: 辅助工具代码。
- `config/`: 应用权限和默认配置。
- `wizard/`: 安装向导的配置和 UI 定义。
- `manifest`: FNOS 应用元数据定义。
- `build.sh`: 构建脚本。

## 许可证

本项目遵循 Apache 2.0 许可证。Grafana Alloy 本身遵循其通过的许可证。
