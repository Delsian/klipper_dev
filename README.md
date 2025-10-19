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
├── katapult/                   # Katapult bootloader source
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
git clone https://github.com/Arksine/katapult.git katapult
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

### Katapult Bootloader Setup

Katapult is a bootloader that enables firmware updates over USB without requiring physical access to the SD card or boot pins. This is highly recommended for development workflows.

#### Building Katapult Bootloader

1. **Configure Katapult**:
```bash
cd katapult
make menuconfig
```

Configure for STM32F103 (SKR Mini v1.3):
- Microcontroller: STM32
- Processor: STM32F103
- Clock Reference: 8 MHz crystal
- **Bootloader Size: 8KiB**
- Communication: USB (PA11/PA12)
- Status LED: Optional (e.g., PC13)

2. **Build Bootloader**:
```bash
make clean
make
```

Output: `out/katapult.bin`

3. **Flash Bootloader** (one-time setup):
```bash
# Method 1: Copy to SD card as firmware.bin and power cycle
cp out/katapult.bin /path/to/sdcard/firmware.bin

# Method 2: Use J-Link
# (Connect J-Link to SWD pins on board)
JLinkExe -device STM32F103RC -if SWD -speed 4000
J-Link> connect
J-Link> loadfile out/katapult.bin 0x08000000
J-Link> exit

# Method 3: Use ST-Link
st-flash write out/katapult.bin 0x08000000
```

4. **Verify Bootloader**:

After flashing Katapult, the board will appear as a USB device with `idVendor=1d50, idProduct=6177`:

```bash
# Check dmesg for Katapult device
dmesg | grep katapult
# Output should show:
# usb X-X: Product: stm32f103xe
# usb X-X: Manufacturer: katapult
```

### Building Klipper Firmware

When using Katapult bootloader, Klipper must be configured with the correct offset.

1. **Configure Build**:
```bash
cd klipper
make menuconfig
```

Configure for your board with Katapult:
- Microcontroller: STM32
- Processor: STM32F103
- **Bootloader offset: 8KiB** (matches Katapult size)
- Clock Reference: 8 MHz crystal
- Communication: USB (PA11/PA12)

2. **Build Firmware**:
```bash
make clean
make
```

Output: `out/klipper.bin`

3. **Flash to Board**:

With Katapult installed, you can flash Klipper over USB:

```bash
# Flash using Katapult's flashtool
../katapult/scripts/flashtool.py -d /dev/ttyACM0 -f out/klipper.bin
```

The board will:
1. Start in Katapult bootloader mode (idProduct=6177)
2. Receive firmware update
3. Reboot into Klipper (idProduct=614e)

Verify Klipper is running:
```bash
dmesg | tail -20
# Should show:
# usb X-X: Product: stm32f103xe
# usb X-X: Manufacturer: Klipper
# usb X-X: SerialNumber: 35FFD8054E4B323817761243
```

### VSCode Integration

Open the workspace file `klipper.code-workspace` for integrated development with preconfigured build and flash tasks.

**Available Tasks** (Ctrl+Shift+P → "Tasks: Run Task"):

*Klipper Firmware:*
- **Build Firmware**: Compile Klipper firmware
- **Clean Build**: Clean and rebuild Klipper
- **Restart Klipper Service**: Restart Klipper Docker container
- **Build and Restart**: Build firmware and restart Klipper service

**Debug Configurations** (F5 or Run and Debug):
- **Run FW (J-Link)**: Debug Klipper firmware on MCU via J-Link with live watch enabled

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
2. **Firmware Changes**: With Katapult, flash via USB using `flashtool.py`. Without Katapult, rebuild and reflash to MCU via SD card or programmer
3. **Config Changes**: Restart Klipper service or use Mainsail UI restart
4. **Keep Logs**: Logs persist in `./logs/` directory for debugging
5. **USB Device States**:
   - Katapult mode: idProduct=6177 (ready for firmware update)
   - Klipper mode: idProduct=614e (normal operation)
6. **Quick Firmware Update**: `cd klipper && make && ../katapult/scripts/flashtool.py -d /dev/ttyACM0 -f out/klipper.bin`

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