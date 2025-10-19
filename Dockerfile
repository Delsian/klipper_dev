FROM debian:bullseye-slim

# Install only runtime dependencies for Klipper service
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libusb-1.0-0 \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/klipper

# Create Python virtual environment
RUN python3 -m venv /opt/venv

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

# Install Python dependencies
RUN /opt/venv/bin/pip install --upgrade pip setuptools wheel

# Copy requirements and install Klipper dependencies
# This requires klippy-requirements.txt to be available during build
COPY klipper/scripts/klippy-requirements.txt /tmp/klippy-requirements.txt
RUN /opt/venv/bin/pip install -r /tmp/klippy-requirements.txt && \
    rm /tmp/klippy-requirements.txt

# Add non-root user for running Klipper service
RUN useradd -m -s /bin/bash klipper && \
    usermod -a -G dialout klipper && \
    chown -R klipper:klipper /opt

# Create socket directory with proper permissions
RUN mkdir -p /tmp/klipper && \
    chown klipper:klipper /tmp/klipper && \
    chmod 755 /tmp/klipper

USER klipper

# Keep container running
CMD ["/bin/bash", "-c", "tail -f /dev/null"]