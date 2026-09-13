# About me

## How I work

I am a software developer with 25 years of experience. The consistent pattern across those years: before any architecture was possible, there was a domain to understand.

Track circuits and axle physics before railway black box analysis. Transformer calibration factors and bypass switch topology before electric energy billing. Reliability theory from economics and industrial literature before building a methodology that the software industry didn't yet have. Wave behavior models before automated trading research. Quaternion mathematics, Kalman filtering, and the geometry of attitude control before spacecraft simulation.

The software was never the first thing. Understanding the physical or operational reality was. Once a domain becomes clear enough - once the structure of the problem reveals itself - the architecture tends to follow naturally. What I build is the artifact of that understanding.

---

## The work, chronologically

**Railway black box analysis (1998-1999)** — My first real project: locomotive black box data, 46 parameters at 2 Hz. It taught me how track circuits actually work — a low-frequency current in the rails, the first wheel axle to enter a segment short-circuits it, and signal lights change across track fragments 2–5 km long. No radio, no electronics. Physics, cascading through infrastructure. The system also monitored brake tests before downhill sections — a mandatory safety check, and also evaluating brake efficiency to detect the equipment degradation at the early stages.

**Electric energy billing (2003–2007)** — My university degree is in Electric Energy System Automated Control. That was the prerequisite, not an addition. The predecessor system stored raw instrument readings and called them data. Real billing requires transformer calibration factors, bypass switch commutation histories, and transformer replacement records. The replacement history is not metadata — it is the calculation. I built the tree-structured grid model that encoded the physical reality, and deployed it to 26,000 metering points at the first customer.

**Cell operator reliability measurement (2012–2017)** — A billing system had a legal availability threshold: ≥ 0.99995. No methodology existed in the software industry to measure this. I went into reliability theory from industrial and economic literature, defined a model for software working and non-working intervals, and built the measurement system from first principles. Along the way we discovered that .NET's garbage collector could freeze a service long enough to look like downtime — I added a new interval type to distinguish it. The "Pillars" visualization I built revealed simultaneous overloads across all system components on a common time axis. The Pillars identified a fixable hardware bottleneck and an unfixable traffic wave from the cell commutator. Knowing which was which changed how the team responded to each.

**Automated trading (2017–2022)** — A five-year research collaboration with a trading domain expert. The first deliverable was not code — it was a shared vocabulary for describing market behavior in terms that could become software. The architecture evolved through consequences: multi-frequency trading forced a balance control module; an undebuggable live session forced full replay logging. On most trading days, the system produced 2–3% capital growth. In the final year, three complete wallet wipes. That combination is a finding. It says something specific about what the wave model captures and what it doesn't see — regime changes the model wasn't built to detect.

**Gaia telescope AOCS digital twin (2024–2026)** — A simulation of the Gaia telescope's Attitude and Orbit Control System, built for research at the Astronomisches Rechen-Institut, Heidelberg University. Scientists had developed ideas for improving attitude control for the next telescope generation; they needed a complete simulation to test them. The existing implementations — separate Python and Java modules, built by different people for different research goals — had never run together and couldn't be connected incrementally. I learned the full control loop: scanning law, inertial rotation, disturbance modeling, star tracker, Kalman filtering, micro propulsion. The hardest conceptual challenge was understanding that the controller never knows what it actually did — it fires the thrusters and then watches whether the stars shift the way they were expected to. Keeping commanded torque, applied torque, and observable effect correctly separated was the conceptual foundation for the entire architecture. The simulation continues in use for next-generation telescope research.

---

## What I want to work on

Real problems where the domain is what matters. Systems where correct answers depend on understanding the physics, the engineering, or the mathematics — not just reading requirement documents. Science, instrumentation, embedded systems, critical infrastructure.

I am currently learning FreeRTOS, bare-metal C and C++, and embedded Linux — not to collect credentials, but to add hardware-level understanding to the software thinking I already have. And, certainly, because of curiosity and fun.

---

## Technology

**Primary:** C# 14, .NET 10, cross-platform development for Linux and Windows

**Currently working with:** FreeRTOS on RP2350, embedded C/C++, I2C devices, bare-metal development

**Databases:** T-SQL / SQL Server (extensive past practice), MongoDB, SQLite

**Architecture:** Microservices, monolith, distributed systems, Docker, Minimal API, Blazor, Windows Services, WPF, WinForms

**Learning:** STM32, KiCAD, Embedded Linux / Yocto, FPGA

<details>

<summary>Bookshelf:</summary>

- Carmine Noviello // Mastering STM32. 2nd ed. 2022
- Jim Yuill, Penn Linder // Hands-On RTOS with Microcontrollers. 2nd ed. 2025
- Mark J. Price // C# 14 and .NET 10 – Modern Cross-Platform Development Fundamentals
- Jörg Rippel // FPGAs. Einsteig, Schaltungen, Projekte
- Andrew Lock // ASP.NET Core in Action, Third Edition
- Naomi Ceder // The Quick Python Book

</details>

<details>

<summary>Out-of-job interests:</summary>

- Family
- Traveling
- Photography

</details>

---

## Project gallery

The following articles contain a brief view of the projects with links to detailed descriptions.
All projects listed in this repository are divided into two categories:

- **[All Projects](./Articles/AllCategoriesOfProjects.md)** - this is the full **illustrated** chronological project list.
- **[Experimental Projects](./Articles/ExperimentsAndEducation.md)** - projects created out of curiosity, or for experimental and educational purposes.
- **[Employment Based Projects](./Articles/EmploymentBasedProjects.md)** - projects I worked on during employment.
- **[Linux and Cross Platform Projects](./Articles/LinuxTargetedProjects.md)** - the projects that can be executed on Linux, and also Cross-Platform projects.

| Date | Name / Category | [Job](./Articles/EmploymentBasedProjects.md) | [Edu](./Articles/ExperimentsAndEducation.md) | Stack and Tags |
| ---- | ---- | ---- | ---- | ---- |
| 2026 | [File Explorer for MacOS](./Articles/39_Shell/Article.md) | | [x] | Swift/Mac, UI/UX, AI-Assisted |
| 2026 | [Font Rasterization SaaS](./Articles/38_EmbeddedFonts/Article.md) | | [x] | .NET, [Linux](./Articles/LinuxTargetedProjects.md), Blazor, SaaS, CI/CD, Blue/Green Deployment, UI/UX, AI-Assisted |
| 2026 | [Local AI Assistant](./Articles/37_LocalAI/Article.md) | | [x] | .NET, [Cross-Platform](./Articles/LinuxTargetedProjects.md), Blazor, UI/UX, AI-Assisted |
| 2026 | [C#/C++ Interop Communication Example](https://github.com/K-S-K/Interop) | | [x] | C#, C++, Linux |
| 2025 | [Simple 3V3 LMR50410 DC-DC Converter](https://github.com/K-S-K/PWR-LMR50410-Simple) | | [x] | PCB development |
| 2024&#8209;2026 | [Gaia telescope Attitude and Orbit Control System Software Digital Twin](Articles/36_GaiaSDT/Article.md) | [x] | | .NET, [Cross-Platform](./Articles/LinuxTargetedProjects.md), Microservices, Docker, Blazor, UI/UX |
| 2024&#8209;2026 | [The FreeRTOS-based timer working on RP2350](https://github.com/K-S-K/Pico-Timer-2) | | [x] | C++, FreeRTOS, Embedded, RP2350, UI/UX |
| 2024&#8209;2025 | [The Experiment with .NET and Raspberry PI](https://github.com/K-S-K/RPIDBClock) | | [x] | .NET, [Linux](./Articles/LinuxTargetedProjects.md), Embedded, I2C, UI/UX |
| 2024 | [Data exchange between Docker containerized applications](https://github.com/K-S-K/CCCS) | | [x] | C++, [Linux](./Articles/LinuxTargetedProjects.md), Docker, WebSockets, IPC |
| 2023&#8209;2024 | [Prototype Board CAD](Articles/30_BBCAD/Article.md) | | [x] | .NET, [Cross-Platform](./Articles/LinuxTargetedProjects.md), Blazor, UI/UX |
| 2023 | [LCD Screen driver for ESP Microcontroller](https://github.com/K-S-K/ESP32-02-OLed-SSD1366) | | [x] | C++, FreeRTOS, Embedded, ESP32 |
| 2021 | [Trading Toy](Articles/28_TradeToy/Article.md) | | [x] | .NET, Windows Desktop, WPF, UI/UX |
| 2021 | [Binance Copy Trading](Articles/27_CopyTrading/Article.md) | [x] | | .NET, Windows Desktop, WPF |
| 2017&#8209;2022 | [Automated Trading System](Articles/04_TDATrading/Article.md) | [x] | | .NET, Windows Desktop, WinForms, T-SQL, High Load, UI/UX |
| 2012&#8209;2017 | [Reliability Analysis System](Articles/05_EWReliability/Article.md) | [x] | | .NET, Windows Service, Windows Desktop, WinForms, T-SQL, Distributed system, Cluster, High Load, UI/UX |
| 2010&#8209;2011 | [Pubmed article editor](Articles/06_PubMedDesktop/Article.md) | [x] | | .NET, Windows Desktop, WinForms, UI/UX |
| 2009&#8209;2010 | [SMS Station](Articles/02_SMSS/Article.md) | [x] | | .NET, Windows Desktop, WinForms, COM Port, PDU, GSM, UI/UX |
| | | | | |
| | | | | |
| 2003&#8209;2007 | [Electric power billing project](Articles/03_ESphere/Article.md) | [x] | | C++, MFC, T-SQL, UI/UX |
| 1998&#8209;1999 | [Railway Black Box Data Viewer](Articles/01_Railway_BB/Article.md) | [x] | | C++, MFC, UI/UX |
| | | | | |

## Documents

[General CV, pdf](Documents/cv-2026-en.pdf)

[Extended CV, pdf](Documents/cv-2026-en-ext.pdf)
