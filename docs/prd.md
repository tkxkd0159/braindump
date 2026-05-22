# Product Requirements Document: Scholarly Planner (Harvard Timeboxing)

## 1. Project Overview
The **Scholarly Planner** is a high-fidelity productivity application designed for researchers, academics, and deep-work practitioners. It leverages the "Harvard Timeboxing" methodology—integrating top priorities, a brain dump for cognitive offloading, and a granular hourly schedule to facilitate peak cognitive focus.

## 2. Target Audience
- **Primary:** Research fellows, PhD students, and academic professionals.
- **Secondary:** Knowledge workers requiring structured, distraction-free planning environments.

## 3. Core Features & User Flows

### 3.1 Daily Planning (Today View)
- **Top Priorities:** A curated list of the 3 most critical tasks for the day. Includes "promote" and "demote" functionality to move tasks between the priorities and the brain dump.
- **Brain Dump:** An uncapped list for capturing minor tasks, tangents, and thoughts. Items can be "promoted" to top priorities.
- **Hourly Schedule:** A vertical timeline (6:00 AM – 10:00 PM) for mapping tasks to specific time blocks. Supports "Deep Work" session labels and visual lock icons for committed blocks.
- **Academic Context:** Daily display of a scholarly quote to set an intellectual tone.

### 3.2 Task Management (All Tasks & Backlog)
- **Central Repository:** A comprehensive view of all active engagements and archived tasks.
- **Filtering & Search:** Ability to filter tasks by "Discipline" (Research, Writing, Admin, Teaching), Status (Pending, Scheduled, Completed), and Date Range.
- **Keyword Search:** Global search across task titles and descriptions.

### 3.3 Navigation & Utility
- **Side Navigation:** Consistent sidebar with access to Today, Tasks, Backlog, Review, Resources, and Archive.
- **Calendar Overlay:** A modal calendar for date selection and viewing task distribution across the month.
- **Session Progress:** A visual indicator in the sidebar footer tracking daily protocol adherence.

## 4. Design Principles (Scholarly Precision)
- **Aesthetic:** High-contrast, disciplined, and minimalist. "Academic excellence" through typography and whitespace.
- **Typography:** Hanken Grotesk (Clean, modern sans-serif).
- **Palette:** 
  - Primary: Midnight Navy (#001f3f)
  - Surface: Pale Scholar Gray/Blue (#f8f9ff)
  - Accents: Disciplined Red for deadlines, Academic Blue for scheduled items.
- **Shape:** Softened precision (Round 4 corners).

## 5. Technical Requirements
- **Responsive Web:** Optimized for desktop focus sessions.
- **Consistency:** Global shared components (TopAppBar, SideNavBar) ensure the "Deep Work Protocol" shell persists across all views.
- **State Management:** Interactivity between the Brain Dump, Priorities, and Schedule (drag-and-drop or promote/demote logic).

## 6. Success Metrics
- **Cognitive Load Reduction:** Measured by the frequency of "Brain Dump" usage.
- **Deep Work Volume:** Total hours committed to "Locked" schedule blocks.
- **Task Velocity:** Efficiency in moving items from Backlog to "Completed" status.
