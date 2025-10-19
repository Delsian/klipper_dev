# Klipper Docker Development Environment

A containerized development environment for Klipper firmware development with integrated debugging support for STM32-based boards.

## Overview

This setup provides a complete Klipper development environment running in Docker containers, with the host system managing the hardware connections (USB serial devices and JTAG debugger). The configuration includes:

- **Klipper**: Main firmware service running in a custom container
- **Moonraker**: API server for printer management
- **Mainsail**: Web-based user interface
- **VSCode Integration**: Configured workspace with build tasks and debugging

## Architecture

```
Host System
├── USB Serial Device (STM32 Board)
├── J-Link Debugger
└── Docker Containers
    ├── Klipper Service (custom build)
    ├── Moonraker (mkuf/moonraker:latest)
    └── Mainsail Web UI (ghcr.io/mainsail-crew/mainsail:latest)
```

## Prerequisites

- Docker and Docker Compose
- Linux host with USB serial device support
- (Optional) J-Link debugger for firmware debugging
- (Optional) VSCode for integrated development

## Directory Structure

```
.
├── docker-compose.yml          # Container orchestration
├── Dockerfile                  # Custom Klipper container
├── klipper/                    # Klipper source code (git submodule)
├── config/                     # Configuration files
│   ├── printer.cfg            # Klipper printer configuration
│   ├── moonraker.conf         # Moonraker API configuration
│   ├── mainsail-config.json   # Mainsail UI settings
│   └── nginx-mainsail.conf    # Nginx configuration
├── logs/                       # Runtime logs
└── gcodes/                     # G-code files storage
```

## Initial Setup

### 1. Clone Repository with Klipper Source

```bash
git clone https://github.com/Klipper3d/klipper.git klipper
```

### 2. Build and Start Containers

```bash
docker compose up -d
```

This will:
- Build the custom Klipper container with Python dependencies
- Start Moonraker API server
- Start Mainsail web interface
- Create shared volumes for configuration and data

### 3. Access Services

- **Mainsail UI**: http://localhost:8010
- **Moonraker API**: http://localhost:7125

## Firmware Development Workflow

### Building Firmware

The Klipper firmware is compiled on the host system, not in the container.

1. **Configure Build**:
```bash
cd klipper
make menuconfig
```

Configure for your board (e.g., STM32F103 for SKR Mini v1.3):
- Microcontroller: STM32
- Processor: STM32F103
- Bootloader offset: 28KiB
- Clock Reference: 8 MHz crystal
- Communication: USB (PA11/PA12)

2. **Build Firmware**:
```bash
make clean
make
```

Output: `out/klipper.bin`

3. **Flash to Board**:
```bash
# Copy to SD card as firmware.bin, or use:
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32f103xe_...
```

### VSCode Integration

Open the workspace file `klipper.code-workspace` for integrated development:

**Available Tasks** (Ctrl+Shift+B):
- **Build Firmware**: Compile Klipper firmware
- **Clean Build**: Clean and rebuild
- **Restart Klipper Service**: Restart Docker container
- **Build and Restart**: Sequential build and service restart

**Debug Configurations**:
- **Debug Klipper MCU (J-Link)**: Attach GDB to running MCU via J-Link
- **Attach to Klipper Python (Docker)**: Debug Python service (requires debugpy setup)

## Hardware Debugging with J-Link

### Setup J-Link GDB Server

1. **Start GDB Server** (in separate terminal):
```bash
JLinkGDBServer -device STM32F103RC -if SWD -speed 4000
```

2. **Launch Debug Session** in VSCode:
- Select "Debug Klipper MCU (J-Link)" configuration
- Set breakpoints in firmware code
- Run debugger (F5)

### GDB Commands

```bash
# Connect manually
gdb-multiarch out/klipper.elf
(gdb) target remote localhost:2331
(gdb) monitor reset
(gdb) load
(gdb) continue
```

## Configuration

### Device Permissions

The container requires access to serial devices. Permissions are handled via:

1. **Device cgroup rules** in `docker-compose.yml`
2. **User group membership**: Container user added to `dialout` group
3. **Volume mounts**: Serial devices mounted from host

Verify device availability:
```bash
docker compose exec klipper ls -l /dev/serial/by-id/
```

### Printer Configuration

Edit `config/printer.cfg` to match your hardware. Key sections:
- `[mcu]`: Serial device path
- `[stepper_*]`: Motor pin assignments and kinematics
- `[extruder]`: Hotend configuration
- `[heater_bed]`: Heated bed settings

After changes, restart the service:
```bash
docker compose restart klipper
```

## Troubleshooting

### Container Logs

```bash
# View all services
docker compose logs -f

# Specific service
docker compose logs -f klipper
docker compose logs -f moonraker
```

### Serial Device Issues

1. **Check device exists**:
```bash
ls -l /dev/serial/by-id/
```

2. **Verify permissions**:
```bash
groups  # Should include 'dialout'
```

3. **Test connection**:
```bash
docker compose exec klipper ls -l /dev/serial/by-id/
```

### Klipper Service Not Starting

1. Check configuration syntax:
```bash
docker compose exec klipper /opt/venv/bin/python /opt/klipper/klippy/klippy.py --check-config /opt/printer_data/config/printer.cfg
```

2. Review logs:
```bash
tail -f logs/klippy.log
```

### Moonraker Connection Issues

Verify socket communication:
```bash
docker compose exec moonraker ls -l /tmp/klipper/klippy.sock
```

## Resource Limits

Container resource limits are configured in `docker-compose.yml`:
- **Klipper**: 1 CPU, 512MB RAM
- **Moonraker**: 1 CPU, 512MB RAM
- **Mainsail**: 0.5 CPU, 256MB RAM

Adjust these based on your host system capabilities.

## Development Tips

1. **Hot Reload**: Klipper Python code changes require service restart
2. **Firmware Changes**: Require rebuild and reflash to MCU
3. **Config Changes**: Restart Klipper service or use Mainsail UI restart
4. **Keep Logs**: Logs persist in `./logs/` directory for debugging

## Network Access

All services use `network_mode: host` for simplicity. Ports used:
- **7125**: Moonraker API
- **8010**: Mainsail web interface

For remote access, configure firewall rules or use reverse proxy.

## Contributing to Klipper

When modifying Klipper source:

1. Work in the `klipper/` directory
2. Follow Klipper coding standards (80-character line limit)
3. Test changes with your hardware
4. Submit pull requests to upstream Klipper repository

## License

This development environment configuration is provided as-is. Klipper itself is licensed under GPL v3.

