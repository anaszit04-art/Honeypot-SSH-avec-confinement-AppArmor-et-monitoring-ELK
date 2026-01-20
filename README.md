# SSH Honeypot with AppArmor Confinement and ELK Monitoring

A Python-based SSH honeypot designed to detect and log intrusion attempts, confined using AppArmor and SECCOMP, with real-time monitoring through the ELK stack (Elasticsearch, Logstash, Kibana).

## 🎯 Overview

This project implements a low-interaction SSH honeypot that mimics an SSH server to attract and log malicious connection attempts. The honeypot is designed with multiple security layers to prevent compromise while collecting valuable threat intelligence data.

**Key Objectives:**
- Capture SSH brute-force attacks and intrusion attempts
- Log credentials, commands, and attacker behavior
- Detect and alert on brute-force patterns
- Provide real-time visualization of attack data
- Ensure honeypot security through OS-level confinement

## ✨ Features

- **SSH Server Simulation**: Mimics OpenSSH server behavior on port 2222
- **Comprehensive Logging**: Captures IP addresses, credentials, timestamps, and commands
- **Brute-Force Detection**: Automatic detection and alerting when threshold exceeded
- **Webhook Alerts**: Real-time notifications via webhook.site
- **AppArmor Confinement**: Restricts file and network access
- **SECCOMP Filtering**: Limits system calls to essential operations only
- **ELK Integration**: Full logging pipeline with Elasticsearch, Logstash, and Kibana
- **Automated Testing**: Includes test scripts for validation

## 🏗️ Architecture

```
┌─────────────────┐
│   Attacker      │
│  (Kali/Hydra)   │
└────────┬────────┘
         │ SSH (port 2222)
         ▼
┌─────────────────────────────┐
│   SSH Honeypot (Python)     │
│  ┌─────────────────────┐    │
│  │  AppArmor Profile   │    │
│  │  SECCOMP Filter     │    │
│  └─────────────────────┘    │
└────────┬────────────────────┘
         │ JSON Logs
         ▼
┌─────────────────────────────┐
│      ELK Stack              │
│  ┌────────────────────┐     │
│  │    Logstash        │     │
│  └────────┬───────────┘     │
│           ▼                 │
│  ┌────────────────────┐     │
│  │  Elasticsearch     │     │
│  └────────┬───────────┘     │
│           ▼                 │
│  ┌────────────────────┐     │
│  │     Kibana         │     │
│  └────────────────────┘     │
└─────────────────────────────┘
```

## 🔧 Prerequisites

- **OS**: Linux (Debian/Ubuntu/Kali recommended)
- **Python**: 3.7+
- **Docker & Docker Compose**: Latest version
- **AppArmor**: Enabled on the system
- **Root/Sudo Access**: Required for security mechanisms

## 📦 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/honeypot-ssh.git
cd honeypot-ssh
```

### 2. Install Dependencies

```bash
chmod +x install_dependencies.sh
sudo ./install_dependencies.sh
```

This script will:
- Update the system
- Install Docker and Docker Compose
- Install Python packages (paramiko, python-seccomp, requests)
- Create log directories
- Add user to docker group

### 3. Fix Docker DNS (if needed)

```bash
chmod +x fix-docker.sh
sudo ./fix-docker.sh
```

### 4. Reboot (recommended)

```bash
sudo reboot
```

## ⚙️ Configuration

### Webhook Configuration

Edit `honeypot_ssh.py` to add your webhook URL:

```python
WEBHOOK_URLS = [
    "https://webhook.site/your-unique-id",
]
```

### Brute-Force Thresholds

Adjust detection sensitivity in `honeypot_ssh.py`:

```python
BRUTE_FORCE_THRESHOLD = 5  # Number of attempts
BRUTE_FORCE_WINDOW = 60    # Time window in seconds
```

### AppArmor Profile

The AppArmor profile is located at `/etc/apparmor.d/python_honeypot` and restricts:
- File access to `/var/log/honeypot/` only
- Network access to port 2222
- Blocks access to sensitive system files

### ELK Stack

Configure Elasticsearch, Logstash, and Kibana in `docker-compose.yml`:
- **Elasticsearch**: Port 9200
- **Kibana**: Port 5601
- **Logstash**: Configured via `logstash.conf`

## 🚀 Usage

### Start the Honeypot

```bash
chmod +x start_honeypot.sh
sudo ./start_honeypot.sh
```

This will:
1. Verify AppArmor profile is loaded
2. Check Python dependencies
3. Start ELK stack containers
4. Wait for Elasticsearch to be ready
5. Launch the SSH honeypot on port 2222

### Access Monitoring Interfaces

- **Kibana**: http://localhost:5601
- **Elasticsearch API**: http://localhost:9200
- **Webhook Alerts**: Check your webhook.site URL

### Monitor Logs

```bash
# Watch honeypot logs in real-time
sudo tail -f /var/log/honeypot/attempts.json

# View honeypot console output
# (Already displayed in the terminal running start_honeypot.sh)
```

### Stop Services

```bash
chmod +x stop_services.sh
sudo ./stop_services.sh
```

## 🧪 Testing

### Basic Connectivity Test

```bash
chmod +x test_honeypot.sh
sudo ./test_honeypot.sh
```

This script:
- Verifies honeypot is running
- Simulates normal connections
- Tests brute-force detection
- Validates log entries

### Brute-Force Detection Test

```bash
chmod +x test_brutefoce.sh
sudo ./test_brutefoce.sh
```

Generates 8 rapid connections to trigger brute-force alert.

### Hydra Attack Simulation

```bash
chmod +x test_hydra_optimized.sh
sudo ./test_hydra_optimized.sh
```

Simulates realistic SSH brute-force attack using Hydra with wordlists.

## 🔒 Security Mechanisms

### AppArmor

Restricts honeypot process to:
- Read/write access to `/var/log/honeypot/` only
- Network binding on port 2222
- Blocks `/etc/passwd`, `/etc/shadow`, `/home/**`

Verify status:
```bash
sudo aa-status | grep python_honeypot
```

### SECCOMP

Whitelist approach limiting system calls to:
- Socket operations (socket, accept, bind, listen)
- I/O operations (read, write, close)
- Time functions (clock_gettime, nanosleep)
- Memory management (mmap, munmap, brk)

Blocks dangerous calls like:
- `execve` (program execution)
- `fork`, `clone` (process creation)
- `ptrace` (debugging)

### Log Analysis

All attempts are logged in JSON format:

```json
{
  "timestamp": "2026-01-20T14:32:45.123456",
  "ip": "192.168.1.100",
  "port": 54321,
  "data": "SSH-2.0-OpenSSH_8.4",
  "type": "ssh_honeypot",
  "attempt_count": 3
}
```

## 📊 Monitoring & Visualization

### Kibana Dashboard

1. Access Kibana at http://localhost:5601
2. Create index pattern: `honeypot-ssh-*`
3. Navigate to Discover to view logs
4. Create visualizations:
   - Attack frequency timeline
   - Top attacker IPs
   - Most common credentials
   - Geographic distribution

### Webhook Alerts

Brute-force alerts include:
- Alert level (HIGH/MEDIUM/LOW)
- Source IP
- Attempt count
- Timestamp
- Data sample

## 📁 Project Structure

```
honeypot-project/
├── honeypot_ssh.py           # Main honeypot script
├── docker-compose.yml        # ELK stack configuration
├── logstash.conf            # Logstash pipeline config
├── install_dependencies.sh  # Dependency installer
├── fix-docker.sh           # Docker DNS fix
├── start_honeypot.sh       # Startup script
├── stop_services.sh        # Shutdown script
├── test_honeypot.sh        # Basic tests
├── test_brutefoce.sh       # Brute-force test
├── test_hydra_optimized.sh # Hydra attack test
├── solution.sh             # Cleanup utilities
└── /etc/apparmor.d/
    └── python_honeypot     # AppArmor profile
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 👥 Authors

- **ZITOUNI Anas** - *Initial work*
- **EL BAOUCHI Anas** - *Initial work*

**Supervisor**: Pr. AIRAJ Mohamed

**Institution**: École Nationale des Sciences Appliquées de Fès (ENSAF)  
**Program**: GDNC 2  
**Academic Year**: 2025-2026

## 📄 License

This project was developed as part of the course "Développement d'applications sécurisées avec Python" at ENSAF.

## 🙏 Acknowledgments

- Pr. AIRAJ Mohamed for guidance and supervision
- ENSAF teaching staff for the course framework
- The open-source community for tools like Paramiko, ELK stack, and AppArmor

## 📚 References

- [Paramiko Documentation](http://www.paramiko.org/)
- [AppArmor Documentation](https://gitlab.com/apparmor/apparmor/-/wikis/home)
- [Elastic Stack Documentation](https://www.elastic.co/guide/index.html)
- [SECCOMP Filter](https://man7.org/linux/man-pages/man2/seccomp.2.html)

---

**⚠️ Disclaimer**: This honeypot is designed for educational and research purposes. Deploy responsibly and ensure compliance with your organization's security policies and local regulations.
