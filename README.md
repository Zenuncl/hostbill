# HostBill Installer (Debian 13 Fork)

> **WARNING: DO NOT use this in production.** This is a **learning project**. The modifications are experimental and have not been tested or endorsed by HostBill. If you really gonna use it, use at your own risk. No warranties, no guarantees, no support. You are entirely responsible for any consequences.

> **DISCLAIMER:** I am not related to the HostBill team and have nothing to do with them. This repository exists solely for personal learning and personal use by myself. If this violates any terms of service, please let me know.

---

This repository contains the HostBill installation scripts originally downloaded from the official source:

```
http://install.hostbillapp.com/install/install.sh
```

The scripts have been modified to support **Debian 13 (Trixie)**.

## Installation on Debian 13

### Prerequisites

- A fresh **Debian 13 (Trixie)** x86_64 system
- **Root** access
- A valid HostBill **license activation code**
- No existing cPanel or DirectAdmin installation

### Steps

1. Clone or download this repository:

   ```bash
   git clone https://github.com/Zenuncl/hostbill.git
   cd hostbill
   ```

2. Make the install script executable:

   ```bash
   chmod +x install_debian_13.sh
   ```

3. Run the installer as root:

   ```bash
   sudo ./install_debian_13.sh <YOUR_LICENSE_CODE>
   ```

   Or run without arguments to be prompted for the license code:

   ```bash
   sudo ./install_debian_13.sh
   ```

   Optionally pass a hostname as the second argument (defaults to the system hostname):

   ```bash
   sudo ./install_debian_13.sh <YOUR_LICENSE_CODE> yourdomain.com
   ```

4. The installer will go through 10 steps automatically:
   - Install base dependencies
   - Download platform installation files
   - Pre-installation checks (disables apache2, sets up ufw firewall)
   - Set up the `hostbill` user and home directory
   - Install and configure **nginx**
   - Install **PHP 8.1** (via sury.org) with required extensions and ionCube Loader
   - Install **memcached**
   - Install **certbot** for SSL certificates
   - Detect the server IP address
   - Enable and restart all services (MariaDB, nginx, PHP-FPM, memcached)

5. Check the install log if anything goes wrong:

   ```bash
   cat /root/hostbillinstall.log
   ```

### What Gets Installed

| Component    | Details                                      |
|--------------|----------------------------------------------|
| Web Server   | nginx                                        |
| PHP          | 8.1 (from packages.sury.org)                 |
| Database     | MariaDB                                      |
| Cache        | memcached                                    |
| SSL          | certbot + self-signed SSL (nginx plugin)     |
| PHP Loader   | ionCube Loader                               |
| Firewall     | ufw (HTTP/HTTPS allowed)                     |
