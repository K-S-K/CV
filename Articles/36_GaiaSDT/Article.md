# Gaia Telescope Software Digital Twin

[Back to the main page](../../README.md)

**Development period:** 2024.05–2026.04

**Practical application:** Testing innovative attitude control approaches for the next-generation telescope[^1].

## The Problem

The scientists at the Astronomisches Rechen-Institut had spent years working with data downloaded from the Gaia telescope. From that experience, they had developed concrete ideas about how attitude control could be improved for a future spacecraft — better disturbance detection, more precise corrections, significant fuel economy over a multi-year mission. To test those ideas, they needed a complete simulation of the Attitude and Orbit Control System (AOCS).

What they had was a collection of partial implementations. Separate modules written in Python and Java by different people, for different research goals, developed by brilliant astronomers and mathematicians — not software engineers. They had attempted to connect these parts using Kafka. It didn't work properly, and it didn't promise to work with necessary performance. The modules had no compatibility in data exchange, units, or coordinate scales. The whole system had never run together. They could not see how it behaved as a complete system.

They needed someone to bridge the gap between their scientific understanding and a working instrument — and that gap is what brought me to the project.

## What I Had to Learn

Before any architecture was possible, I had to understand the system the software was meant to simulate.

I started with the signal and data flow between the AOCS components — what each device does, at what frequency, with what delay, and under what physical constraints. The central structural insight came early: there is a strict boundary between **physical reality** and **what the system can observe**. The spacecraft exists in physics. The control system can only act on what its sensors report. These two levels must be kept separate in the simulation, or the model produces results that could never happen in hardware.

Working through this with my colleagues, I built an understanding of each component in the control loop:

- **Scanning Law** — the nominal attitude plan that defines where the spacecraft should be pointing at every moment of the mission. Two implementations: *inertial movement*, a pure rotation based on the equations of motion (used for testing and calibration); and *orbital plan movement*, a rotation with a spiral offset designed to scan the entire planned sky area over time
- **Inertial rotation** — the physics model of how the spacecraft actually moves under applied torques and disturbances
- **Disturbances** — micrometeorite impacts, thermal deformation clanks, solar radiation pressure, fuel sloshing in tanks
- **Star Catalog** — the sky map that supports sensor modeling; given a pointing direction and a field of view, it returns the list of stars visible from that direction, enabling the Star Tracker's lost-in-space constellation recognition
- **Star Tracker** — photographs a patch of sky, uses the Star Catalog to recognize constellation patterns, returns an *approximation* of orientation with hardware-specific errors
- **Focal Plane** — measures angular velocity at high precision from star movement across the CCD arrays, with hardware-specific delays
- **Kalman Filter** — fuses Star Tracker and Focal Plane data, decides which measurements are trustworthy, produces a verified attitude estimate
- **Controller** — compares verified attitude against the Scanning Law plan, calculates the torque correction needed
- **Micro Propulsion System** — takes the required torque, applies hardware constraints (thruster geometry and power), and produces the *actually applied torque* that feeds back into the physics model

The hardest conceptual challenge was twofold.

First: **quaternion mathematics** — the algebra for rotating vectors between reference frames and for integrating angular motion over time. Once this clicked, everything about orientation representation became consistent.

Second, and more fundamental: **the controller never knows what it actually did**. It calculates the torque it *should* produce. It fires the thrusters. And then it waits — watching whether the stars in its field of view shift the way they were expected to. There is no direct feedback. The system infers its own effect from a delayed, noisy physical response. Understanding this gap between commanded torque, applied torque, and observable effect — and keeping those three things correctly separated throughout the simulation — was the conceptual foundation for the entire architecture.

I don't claim to understand all the mathematics at the depth my colleagues do. What I learned was enough to implement their algorithms correctly, connect the implementations into a coherent system, and build something they can actually use.

## The Architecture

The existing implementations couldn't be connected incrementally — the incompatibilities were too fundamental. They had to be rewritten.

My proposal was a **hybrid architecture**: all modules run together as a monolith when performance matters, computational experiments completing quickly with minimal overhead; or selected modules wrap as microservices when resource constraints require it. The Star Catalog, for example, can consume more memory than a typical workstation can spare — it runs as a persistent separate service and stays warm between experiments to eliminate startup delay.

I eliminated Kafka entirely. Minimal API endpoints are faster, carry no external dependencies, and do everything the project actually needs. A single bash script launches the appropriate topology for the experiment at hand. Scientists configure experiments, observe results, and export data through a browser UI.

![The Computational Experiment](Images/Fig_01_SDT-UI-Q.png)

**Fig. 1** — A computational experiment in progress. Around the midpoint, a micrometeorite strikes the spacecraft. The model detects the disturbance and activates the thrusters to return to the planned attitude.

![Clank Detection](Images/Fig_02_SDT-UI-Clank-Along.png)

**Fig. 2** — Two sequential clank detections. The propagation of each disturbance is visible as a detectable change in the measured angular velocity.

## What It Enabled

Before this tool, the scientists had partial models that worked in isolation — slowly, and never as a complete system. Now they have a configurable, production-ready framework that simulates the full AOCS loop from disturbance through sensing, filtering, control, and propulsion, and produces results they can export and analyze.

The tool continues in use. My contract has formally ended, but the collaboration has not — my colleagues continue to use the simulation to test ideas for the next telescope mission: improved Kalman filtering, better disturbance recognition, more precise attitude corrections that would reduce fuel consumption over a multi-year mission. The simulation is the instrument they use to evaluate those ideas in silico before anything flies.

## Technical Details

**Architecture:** Cross-platform .NET, deployable as a monolith or distributed across Docker containers — developer machine, local Docker network, or distributed hardware.

**Components:**
- Library assemblies — mathematical abstractions and infrastructure
- Module assemblies — Scanning Law (two variants), inertial rotation, disturbances, Star Catalog, Star Tracker, Focal Plane, Kalman Filter, Controller, Micro Propulsion System
- Laboratory — integrates modules and manages communication between them
- REST API service — hosts the Laboratory
- UI Service (Blazor) — experiment configuration, progress monitoring, results visualization, CSV export
- Optional Star Catalog service — runs separately when memory requirements exceed workstation capacity

**Implementation technologies:** .NET 10, C#, Blazor.

**Developer tools:** Microsoft Visual Studio Code.

**Current status:** Development in progress.

[^1]: Research at the Astronomisches Rechen-Institut, Heidelberg University.
