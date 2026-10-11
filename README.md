# Nim Playground

Small nim programs dropped to test some language features.

## Scripts

### Root

#### 1. http-ping

A minimal HTTP latency checker.
Performs one or more HTTP (or HEAD) requests and reports response time.

**Usage**

```bash
nim c -r ping.nim <url> <nRequests> [--head]
nim c -r ping.nim https://example.com 5
```

---

#### 2. certCheck

Checks the TLS certificate expiration date of a remote host. This was a PITA.

> _Requires a Unix-like environment with OpenSSL available(Linux/WSL recommended)._

**Usage**

```bash
nim c -r certCheck.nim <hostname>
nim c -r certCheck.nim example.com
```

---

#### 3. isPortInUse

Checks whether a port is in use.

**Usage**

```bash
nim c -r isPortInUse.nim <port> [port...]
nim c -r isPortInUse.nim 80 21
```

---

#### 4. clipboardTest

Checks whether a file of some extension (images in this case) is currently copied to clipboard.

**Usage**

```bash
nim c -r clipboardTest.nim <port> [port...]
nim c -r clipboardTest.nim
```

---

#### 5. hasher

Generates a sha256 hash of a file using streams. Useful when adding hashes to some whitelist.

**Usage**

```bash
nim c -r hasher [options [-d (for directories), -h]] <path>
nim c -r hasher your_path
```

---

#### 6. task_mgr

Task manager, testing IO from the cli.

**Usage**

```bash
nim c -r task_mgr
```

---


#### 7. big_file_reporter

Finds paths with big files and displays them by levels.

**Usage**

```bash
nim c -r task_mgr
```

---

### Nimgui

Applications with a visual interface.

1. **Port Checker:** A simple port checker.
   ![Port Checker](/nimgui/gui/port_checker/port.PNG)

2. **License Generator:** Generates a key and save them to a text file.
   ![NimKey Genie](/nimgui/gui/lickeygen/keygen.png)


