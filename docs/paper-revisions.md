# AquaWatch paper — revisions needed

Review of `Appdev Documents(2).docx` against the actual parts on hand and the
code in this repository. Items are grouped by the kind of change each needs.

**The headline problem:** the paper documents three components the team does not
own — a 1-digit 7-segment display, an SW-520D tilt switch, and a 9V battery with
barrel jack — and never mentions the Flutter app that makes up most of this
repository.

Parts actually on hand: Arduino Uno R3, water level sensor, 3 LEDs, 4 resistors,
a buzzer, a breadboard, and a USB cable. No battery, so the board is powered over
USB from a laptop at all times.

---

## 1. Remove — hardware that does not exist

Each of these appears in several places. All occurrences must go, not just the
Table 1 row.

| Component | Sections to edit |
| --- | --- |
| 1-digit 7-segment display (D2–D8) | Executive Summary (final paragraph); Table 1; Hardware Assembly Layout → "Digital Header Block"; Multi-Stage Exclusive State Machine → "7-Segment" column; Depth Level Mapping & Response Matrix → "7-Segment Output" column; Key Findings → "Zero-Latency Display"; Conclusion |
| SW-520D tilt switch (A1) | Executive Summary ("a tilt sensor switch (SW-520D) on analog pin A1 to detect drinking activity"); Table 1; Hardware Assembly Layout → "Analog Header Block"; Conclusion ("tilt motion detection", "an SW-520D tilt switch") |
| 9V battery + DC barrel jack | Executive Summary ("powered portably via a 9V battery with a DC Barrel jack connector"); Table 1 → "Power Unit" row; Key Findings → "Power Stability"; Conclusion ("self-contained") |
| 90-degree illustration board enclosure, hot-glue sealing | Executive Summary; the whole "Chassis and Waterproofing Construction" section |

Removing the battery changes a claim the paper leans on: the device is **not**
portable or off-grid. It runs on USB power from a laptop. Any sentence calling it
standalone, portable, or self-contained needs rewriting.

With the 7-segment gone, D2–D8 are free. The three LEDs on D10/D11/D12 and the
buzzer on D9 can stay exactly as Table 1 documents them — that part of the pin
map survives unchanged.

## 2. Fix — internal contradictions

These are wrong independently of the hardware, and a panel could catch them.

**2.1 The mapping formula cannot produce the results table.**
"Calibration and Depth Mapping Logic" says raw input is mapped "linearly across
10 integer levels (0 though 9)". Written the obvious way, `map(raw, 50, 550, 0, 9)`
returns level 0 for raw 105, but Table 2 reports level 1 — and it is off by one on
all ten trials. The formula that reproduces the table is:

    level = constrain(map(raw, 50, 550, 0, 10), 0, 9);

State the formula explicitly in the paper rather than describing it in prose.

**2.2 The state ranges contradict the levels they claim.**
Levels step every 50 raw counts, so level 3 begins at raw 200 and level 7 at raw
400. The state machine table instead claims 161 and 381. At raw 381 the green LED
would be on while the level is still 6.

| State | Table says | Should be |
| --- | --- | --- |
| Low Water (levels 1–2) | 50 – 160 | 50 – 199 |
| Halfway (levels 3–6) | 161 – 380 | 200 – 399 |
| Full (levels 7–9) | 381 – 550+ | 400 – 550+ |

**2.3 An empty tank raises no alarm.**
State 0 (Dry/Empty, raw < 50) is documented as all LEDs off and silent, while
State 1 (Low Water) beeps. In a low-water alert system the completely empty tank
is the most urgent case, so the current design stays quiet exactly when it should
not. Recommend folding level 0 into the Low Water state: red LED on, buzzer
pulsing. This changes one row of the state table and one row of the results matrix.

**2.4 The buzzer is described as active but driven like a passive one.**
Table 1 lists an "Active Buzzer — 5V Piezoelectric Acoustic Transducer", while the
Software and Toolchain section says the firmware uses `tone()`. An active buzzer
contains its own oscillator and is switched with `digitalWrite()`; `tone()` is for
passive buzzers. Pick one and make both sections agree. Note the physical part has
not been identified yet — see section 5.

**2.5 Resistor value disagrees with itself.**
"Circuit Interconnection Architecture" says "Currently limiting 200 Omega
resistors"; Table 1 and Hardware Assembly Layout say 220 ohm. Use 220 throughout.
("Currently limiting" should also read "Current-limiting".)

**2.6 The sensor is called four different things.**
"conductive water level sensor module" (Executive Summary), "Resistive Immersion
Board" (Table 1), "conductive water sensor" (Calibration), "resistive depth
sensor" (Conclusion). Choose one term and use it everywhere.

## 3. Add — what is missing

**3.1 The Flutter application is absent from the paper.**
This is the largest gap. The repository contains a working Flutter app with USB
serial and Wi-Fi connection paths, live readings, calibration, an event log with
CSV export, and a test suite — none of it documented. With the 7-segment display
removed, the app *is* the readout, which also repairs the IoT framing the
Executive Summary sets up but the current system never delivers.

**3.2 "Production C++ Firmware Code" is an empty heading.**
The section has a title and no code underneath it.

**3.3 The document contains no images at all.**
The .docx has zero embedded media files. Three sections promise screenshots and
deliver captions only: "Hardware Assembly Layout", "Serial Diagnostic Telemetry
Output", and "Chassis and Waterproofing Construction".

**3.4 Two claims contradict each other about connectivity.**
The Executive Summary says performance "may be affected by sensor accuracy, power
availability, Wi-Fi connectivity, cloud-service operation, and mobile notification
settings" — none of which the described system has. The Conclusion then says the
system "eliminates reliance on external cloud services or mobile networks", while
Recommendations lists a mobile dashboard as future work. If the app is written
into the paper, all three passages need rewriting together.

**3.5 The ten trials may need re-running.**
Table 2 reports raw values, 7-segment output, and sub-50 ms response times. If
those trials were run on a build that included the display and battery, the data
has to be collected again on the real hardware.

## 4. Citations and wording

**4.1 The YouTube citation is wrong on three counts.** Currently:

> Arduino Electronics Tutorials. (2024). *Water Level Indicator using Arduino UNO, LEDs, and Piezo Buzzer* [Video File]. YouTube.

The actual video at that URL is:

> Carbonilla, S. M. (2023, November 15). *Arduino project: Water level sensor with LEDs and a buzzer as an indicator* [Video]. YouTube. https://www.youtube.com/watch?v=sdFKLdLKilA

**4.2 Verify these references exist and the details are correct.** Confirm volume,
issue, page numbers and DOIs before submission:

- Kumar, S., Patel, R., & Sharma, A. (2025). *Journal of Embedded Systems and Automation, 14*(2), 112–125.
- Palermo, E., Rossi, M., & Marino, F. (2022). *IEEE Access, 10*, 45210–45228.

**4.3 Smaller consistency fixes:**

| Where | Issue |
| --- | --- |
| Cover vs. Approval Sheet | "Ms. Janice Arradaza Capule" vs "Mrs. Janice Arradaza Capule" |
| Cover vs. Executive Summary | "Smart Water **Tank** Level Monitor" vs "Smart Water Level Monitor"; also AquaWatch vs Aquawatch capitalisation |
| Table of Contents | "Conclusion and Recommentations" → "Recommendations" |
| Table of Contents vs heading | "Software and Toolchain Requirement" vs "...Requirements" |
| System Design and Development Process | "an interactive hardware-software engineering pipeline" → "iterative" |
| Circuit Interconnection Architecture | "grounded though a shared negative rail" → "through" |
| Calibration and Depth Mapping Logic | "10 integer levels (0 though 9)" → "through" |
| Throughout | "Omega" spelled as a word; use the symbol or "ohm" consistently |
| Table of Contents | page numbers need regenerating after the edits |

## 5. Confirm before rewriting

Questions only the team can answer. The rewrite depends on them.

- [ ] **Which buzzer is it?** A passive buzzer shows a visible coil or exposed PCB
      on the underside; an active one is sealed, usually with a sticker. This
      decides item 2.4 and whether the firmware uses `tone()` or `digitalWrite()`.
- [ ] **Was an enclosure ever built?** If not, the whole "Chassis and Waterproofing
      Construction" section goes.
- [ ] **Where did the Table 2 trial data come from?** If it was not measured on the
      current build, it has to be re-measured.
- [ ] **Is the breadboard actually 400-point?** The paper states this specifically.
- [ ] **Does the Flutter app go into the paper?** This is the biggest structural
      decision. It affects the Executive Summary, a new section of its own, the
      Conclusion, and the Recommendations.
