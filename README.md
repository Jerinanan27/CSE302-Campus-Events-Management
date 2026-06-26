# Campus Events Management System

An Oracle APEX application for managing university events, activities, registrations, and attendance — built on a normalized relational schema with PL/SQL triggers, role-based authorization, and an analytics/reporting layer (aggregate queries, multi-table joins, parameterized reports, and dashboards).

> **Course:** CSE302 — Database Systems, East West University (Spring 2024)
> **Platform:** Oracle APEX · Oracle SQL / PL/SQL
> **Team project** (4 members) — my contribution centered on schema design, the reporting/analytics pages, and trigger logic.

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Entity–Relationship Model](#entityrelationship-model)
- [Database Schema](#database-schema)
- [Triggers (PL/SQL)](#triggers-plsql)
- [Reporting & Analytics Layer](#reporting--analytics-layer)
- [Sample Queries](#sample-queries)
- [Authorization Model](#authorization-model)
- [Screenshots](#screenshots)
- [Running the Project (APEX Import)](#running-the-project-apex-import)
- [Repository Structure](#repository-structure)
- [Limitations & Future Work](#limitations--future-work)

---

## Overview

The system lets a university manage the full event lifecycle: an admin creates **Events**, each event contains one or more **Activities** (a seminar, workshop, championship, etc.) scheduled into **Rooms** and **Timeslots**; **Users** register for activities, attendance is recorded, and users leave **Feedback**. Events can be backed by **Sponsors**. On top of this transactional core sits a reporting layer with aggregate and multi-table reports plus five interactive charts.

Key capabilities:

- Normalized multi-table schema with enforced referential integrity
- **PL/SQL triggers** for capacity enforcement and automatic event-status transitions
- **Master–detail** form (Event → Activities + Sponsors)
- **Aggregate** report (registrations per activity) and **multi-table join** report (user event history)
- **Parameterized** report (filter activities by event name)
- **5 dashboards/charts** — average rating per event, participants per event, events per room, registrations over time, event duration
- **Role-based, page-wise authorization** (Administrator / Contributor / Reader)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | Oracle Database (Oracle APEX cloud workspace) |
| Procedural logic | PL/SQL (triggers, capacity checks) |
| UI / Application | Oracle APEX (low-code) |
| Auth | APEX Custom Authentication + page-level Authorization Schemes |

---

## Entity–Relationship Model

The schema models nine core entities. Relationships (read "one ─ many" unless noted):

- **Role** ─< **Users** — each user has exactly one role; a role applies to many users.
- **Users** ─< **Register** >─ **Activity** — registration is the associative entity resolving the many-to-many between users and activities.
- **Event** ─< **Activity** — an event contains many activities; each activity belongs to one event.
- **Category** ─< **Activity** — each activity has one category (Seminar, Championship, Workshop, Webinar, Contest).
- **Room** ─< **Activity** — an activity is held in one room.
- **TimeSlot** ─< **Activity** — an activity occupies one timeslot.
- **Register** ─< **Attendance** — attendance records reference a registration (check-in time).
- **Event** ─< **Feedback** >─ **Users** — feedback links a user to an event (rating + comments).
- **Event** ─< **Sponsor** — an event may have many sponsors.

> See [`docs/er_model.png`](docs/er_model.png) and [`docs/relational_model.png`](docs/relational_model.png) for the full diagrams.

---

## Database Schema

Primary keys in **bold**, foreign keys in _italics_.

### Role
| Column | Type | Notes |
|--------|------|-------|
| **RoleID** | NUMBER(10) | PK |
| RoleName | VARCHAR2(255) | e.g. Admin, Organizer, Volunteer |
| Department | VARCHAR2(255) | |
| Club | VARCHAR2(255) | |

### Users
| Column | Type | Notes |
|--------|------|-------|
| **UserID** | NUMBER(10) | PK |
| Username | VARCHAR2(50) | |
| Password | VARCHAR2(50) | (demo data — see note below) |
| Email | VARCHAR2(100) | |
| ProfilePicture | BLOB | |
| NotificationSettings | VARCHAR2(100) | |
| Preference | VARCHAR2(255) | |
| _RoleID_ | NUMBER(10) | FK → Role |

### Event
| Column | Type | Notes |
|--------|------|-------|
| **EventID** | NUMBER(10) | PK |
| Title | VARCHAR2(255) | |
| HostedBy | VARCHAR2(50) | |
| Budget | NUMBER(10) | |
| Description | NVARCHAR2(500) | |
| Location | VARCHAR2(100) | |
| Capacity | NUMBER(10) | |
| Status | VARCHAR2(50) | Scheduled / Event Over (auto-set by trigger) |
| Start_Date | DATE | |
| End_Date | DATE | |
| Banner | BLOB | |

### Activity
| Column | Type | Notes |
|--------|------|-------|
| **ActivityID** | NUMBER | PK |
| ActivityName | VARCHAR2 | |
| Fee | NUMBER | |
| ActivityDay | VARCHAR2 | |
| _Event_EventID_ | NUMBER | FK → Event |
| _Room_RoomID_ | NUMBER | FK → Room |
| _Category_CategoryID_ | NUMBER | FK → Category |
| _TimeSlot_TimeSlotID_ | NUMBER | FK → TimeSlot |
| ActivityDescription | NVARCHAR2 | |

### Register
| Column | Type | Notes |
|--------|------|-------|
| **RegistrationID** | NUMBER(10) | PK |
| _Users_UserID_ | NUMBER(10) | FK → Users |
| _Activity_ActivityID_ | NUMBER | FK → Activity |
| RegistrationDate | DATE | |

### Attendance
| Column | Type | Notes |
|--------|------|-------|
| **AttendanceID** | NUMBER | PK |
| CheckInTime | DATE | |
| _Register_RegistrationID_ | NUMBER | FK → Register |

### Feedback
| Column | Type | Notes |
|--------|------|-------|
| **FeedbackID** | NUMBER(10) | PK |
| Rating | NUMBER(1) | 1–5 |
| Comments | CLOB | |
| SubmissionTime | DATE | |
| _Event_EventID_ | NUMBER(10) | FK → Event |
| _Users_UserID_ | NUMBER(10) | FK → Users |

### Room
| Column | Type | Notes |
|--------|------|-------|
| **RoomID** | NUMBER(10) | PK |
| RoomName | VARCHAR2(255) | |
| Status | VARCHAR2(255) | Available / Unavailable |

### Category
| Column | Type | Notes |
|--------|------|-------|
| **CategoryID** | NUMBER(10) | PK |
| CategoryName | VARCHAR2(255) | |

### TimeSlot
| Column | Type | Notes |
|--------|------|-------|
| **TimeSlotID** | NUMBER(10) | PK |
| start_time | DATE | |
| end_time | DATE | |

### Sponsor
| Column | Type | Notes |
|--------|------|-------|
| **SponsorID** | NUMBER(10) | PK |
| SponsorName | VARCHAR2(100) | |
| Budget | NUMBER | |
| _Event_EventID_ | NUMBER(10) | FK → Event |

> Full DDL is in [`sql/schema.sql`](sql/schema.sql).

---

## Triggers (PL/SQL)

Two triggers enforce business rules at the database layer rather than only in the UI.

### 1. Capacity enforcement — block registration when an activity is full

Prevents a `Register` insert if the related event has already reached its capacity, raising a custom error (`ORA-20001`) that surfaces in the APEX UI.

```sql
CREATE OR REPLACE TRIGGER trg_check_capacity
BEFORE INSERT ON Register
FOR EACH ROW
DECLARE
    v_capacity      Event.Capacity%TYPE;
    v_current_count NUMBER;
    v_event_id      Event.EventID%TYPE;
BEGIN
    -- Find the event behind the activity being registered for
    SELECT a.Event_EventID
      INTO v_event_id
      FROM Activity a
     WHERE a.ActivityID = :NEW.Activity_ActivityID;

    -- Event capacity
    SELECT e.Capacity
      INTO v_capacity
      FROM Event e
     WHERE e.EventID = v_event_id;

    -- Current registrations across all activities of this event
    SELECT COUNT(*)
      INTO v_current_count
      FROM Register r
      JOIN Activity a ON r.Activity_ActivityID = a.ActivityID
     WHERE a.Event_EventID = v_event_id;

    IF v_current_count >= v_capacity THEN
        RAISE_APPLICATION_ERROR(-20001,
            'This activity has reached its capacity.');
    END IF;
END;
/
```

### 2. Auto event-status transition — mark events as "Event Over"

Sets `Status = 'Event Over'` automatically when the event end date has passed, so reports and the home page always reflect current state.

```sql
CREATE OR REPLACE TRIGGER trg_set_event_status
BEFORE INSERT OR UPDATE ON Event
FOR EACH ROW
BEGIN
    IF :NEW.End_Date < SYSDATE THEN
        :NEW.Status := 'Event Over';
    ELSE
        :NEW.Status := 'Scheduled';
    END IF;
END;
/
```

> Both triggers are in [`sql/triggers.sql`](sql/triggers.sql). The capacity trigger is demonstrated in [`docs/screenshots/trigger_capacity_error.png`](docs/screenshots/).

---

## Reporting & Analytics Layer

| Page | Type | Description |
|------|------|-------------|
| Registration Per Activity Report | **Aggregate** (`GROUP BY` + `COUNT`) | Total registrations per activity |
| My Profile / Event History | **Multi-table join** | Past events a user has attended |
| Parameterized Report | **Bind variable** | Activities filtered by a user-supplied event name |
| Average Rating Per Event | Bar chart | Mean feedback rating per event |
| Participants Per Event | Bar chart | Distinct registrants per event |
| Number of Events Per Room | Line chart | Room utilization |
| User Registrations Over Time | Column chart | Registrations grouped by month |
| Event Duration | Line chart | End − start span per event |

---

## Sample Queries

These mirror the report/chart pages above. Full set in [`sql/reports.sql`](sql/reports.sql).

**Registrations per activity (aggregate):**

```sql
SELECT a.ActivityID,
       a.ActivityName,
       COUNT(r.RegistrationID) AS total_registrations
  FROM Activity a
  LEFT JOIN Register r
         ON r.Activity_ActivityID = a.ActivityID
 GROUP BY a.ActivityID, a.ActivityName
 ORDER BY total_registrations DESC;
```

**User event history (multi-table join):**

```sql
SELECT u.Username,
       e.Title       AS event_title,
       e.Start_Date,
       at.CheckInTime
  FROM Users u
  JOIN Register   r  ON r.Users_UserID          = u.UserID
  JOIN Activity   a  ON a.ActivityID            = r.Activity_ActivityID
  JOIN Event      e  ON e.EventID               = a.Event_EventID
  JOIN Attendance at ON at.Register_RegistrationID = r.RegistrationID
 WHERE u.UserID = :APP_USER_ID
 ORDER BY e.Start_Date DESC;
```

**Average rating per event:**

```sql
SELECT e.Title,
       ROUND(AVG(f.Rating), 2) AS avg_rating,
       COUNT(f.FeedbackID)     AS n_responses
  FROM Event e
  JOIN Feedback f ON f.Event_EventID = e.EventID
 GROUP BY e.Title
 ORDER BY avg_rating DESC;
```

**Registrations over time (monthly):**

```sql
SELECT TO_CHAR(r.RegistrationDate, 'Month') AS reg_month,
       COUNT(*)                             AS registered_users
  FROM Register r
 GROUP BY TO_CHAR(r.RegistrationDate, 'Month'),
          EXTRACT(MONTH FROM r.RegistrationDate)
 ORDER BY EXTRACT(MONTH FROM r.RegistrationDate);
```

**Parameterized report (filter by event name):**

```sql
SELECT a.ActivityID,
       a.ActivityName,
       a.Fee,
       a.ActivityDay,
       a.ActivityDescription
  FROM Activity a
  JOIN Event e ON e.EventID = a.Event_EventID
 WHERE e.Title = :P77_EVENT_NAME;
```

---

## Authorization Model

Custom authentication with three page-wise authorization tiers:

| Role | Rights |
|------|--------|
| **Administrator** | Full access — create users, manage Events/Category/Room/Timeslot, Event Activity Information |
| **Contributor** | Create/edit forms (Event Form, Registration, Feedback, Attendance, reports) |
| **Reader** | Read-only access to Events, Activities, My Profile, Feedback Form |

Example page-level rules: *Create Users* → Administrator only; *Event Form* → Contributor; *Events report* → Reader.

---

## Screenshots

| View | File |
|------|------|
| Home — upcoming events | `docs/screenshots/home.png` |
| Events report + form | `docs/screenshots/events.png` |
| Master-detail (Event → Activity + Sponsor) | `docs/screenshots/event_activity_info.png` |
| Registration Per Activity (aggregate) | `docs/screenshots/registrations_per_activity.png` |
| Average Rating chart | `docs/screenshots/avg_rating.png` |
| Participants Per Event chart | `docs/screenshots/participants_per_event.png` |
| Registrations Over Time chart | `docs/screenshots/registrations_over_time.png` |
| Capacity trigger error (ORA-20001) | `docs/screenshots/trigger_capacity_error.png` |

> Place exported screenshots in `docs/screenshots/`.

---

## Running the Project (APEX Import)

This is an Oracle APEX application, so it runs inside an APEX workspace rather than as a standalone server.

1. **Create / log in** to an Oracle APEX workspace (e.g. [apex.oracle.com](https://apex.oracle.com)).
2. **Build the schema:** run [`sql/schema.sql`](sql/schema.sql) in SQL Workshop → SQL Scripts.
3. **Add triggers:** run [`sql/triggers.sql`](sql/triggers.sql).
4. **(Optional) seed data:** run [`sql/seed_data.sql`](sql/seed_data.sql).
5. **Import the app:** App Builder → Import → select the exported [`apex/f<APP_ID>.sql`](apex/) application export.
6. Run the application and log in with a seeded user.

> **To export from APEX:** App Builder → your app → *Export / Import* → *Export* → SQL file. Commit that file under `apex/`.

---

## Repository Structure

```
.
├── README.md
├── sql/
│   ├── schema.sql          # DDL — tables, PKs, FKs
│   ├── triggers.sql        # capacity + event-status triggers
│   ├── reports.sql         # report/chart queries
│   └── seed_data.sql       # sample rows (no real credentials)
├── apex/
│   └── f<APP_ID>.sql       # APEX application export
└── docs/
    ├── er_model.png
    ├── relational_model.png
    └── screenshots/
```

---

## Limitations & Future Work

- Demo passwords are illustrative only — a production build should hash credentials (the course project stored plaintext for grading convenience; **do not commit real credentials**).
- Capacity is enforced at event level; activity-level capacity would need a per-activity limit column.
- Image upload to reports was not implemented.
- Future: email notifications on registration, waitlist handling when capacity is hit, and a calendar view.

---

## Acknowledgements

CSE302 Database Systems group project (4 members), East West University, Spring 2024.# CSE302-Campus-Events-Management
Oracle APEX campus events management system with a normalized relational schema, PL/SQL triggers, and an SQL reporting/analytics layer (aggregate queries, joins, parameterized reports, dashboards). CSE302 Database Systems, EWU.
