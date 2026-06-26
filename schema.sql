-- ============================================================================
--  Campus Events Management System  —  Schema (DDL)
--  Course : CSE302 Database Systems, East West University (Spring 2024)
--  Engine : Oracle Database / Oracle APEX
--
--  Run order:
--    1. schema.sql   (this file)   — tables, primary keys, foreign keys
--    2. triggers.sql               — business-rule triggers
--    3. seed_data.sql  (optional)  — sample rows
--
--  Tables are created parent-first so foreign keys resolve cleanly.
-- ============================================================================

-- ---------------------------------------------------------------------------
--  Independent (parent) tables — no outgoing foreign keys
-- ---------------------------------------------------------------------------

CREATE TABLE Role (
    RoleID       NUMBER(10)      NOT NULL,
    RoleName     VARCHAR2(255),
    Department   VARCHAR2(255),
    Club         VARCHAR2(255),
    CONSTRAINT pk_role PRIMARY KEY (RoleID)
);

CREATE TABLE Category (
    CategoryID   NUMBER(10)      NOT NULL,
    CategoryName VARCHAR2(255),
    CONSTRAINT pk_category PRIMARY KEY (CategoryID)
);

CREATE TABLE Room (
    RoomID       NUMBER(10)      NOT NULL,
    RoomName     VARCHAR2(255),
    Status       VARCHAR2(255),
    CONSTRAINT pk_room PRIMARY KEY (RoomID)
);

CREATE TABLE TimeSlot (
    TimeSlotID   NUMBER(10)      NOT NULL,
    start_time   DATE,
    end_time     DATE,
    CONSTRAINT pk_timeslot PRIMARY KEY (TimeSlotID)
);

CREATE TABLE Event (
    EventID      NUMBER(10)      NOT NULL,
    Title        VARCHAR2(255),
    HostedBy     VARCHAR2(50),
    Budget       NUMBER(10),
    Description  NVARCHAR2(500),
    Location     VARCHAR2(100),
    Capacity     NUMBER(10),
    Status       VARCHAR2(50),     -- 'Scheduled' / 'Event Over' (set by trigger)
    Start_Date   DATE,
    End_Date     DATE,
    Banner       BLOB,
    CONSTRAINT pk_event PRIMARY KEY (EventID)
);

-- ---------------------------------------------------------------------------
--  Dependent tables — declared after their parents
-- ---------------------------------------------------------------------------

CREATE TABLE Users (
    UserID               NUMBER(10)   NOT NULL,
    Username             VARCHAR2(50),
    Password             VARCHAR2(50),  -- demo only; hash in production
    Email                VARCHAR2(100),
    ProfilePicture       BLOB,
    NotificationSettings VARCHAR2(100),
    Preference           VARCHAR2(255),
    Role_RoleID          NUMBER(10),
    CONSTRAINT pk_users PRIMARY KEY (UserID),
    CONSTRAINT fk_users_role
        FOREIGN KEY (Role_RoleID) REFERENCES Role (RoleID)
);

CREATE TABLE Activity (
    ActivityID           NUMBER       NOT NULL,
    ActivityName         VARCHAR2(255),
    Fee                  NUMBER,
    ActivityDay          VARCHAR2(50),
    Event_EventID        NUMBER(10),
    Room_RoomID          NUMBER(10),
    Category_CategoryID  NUMBER(10),
    TimeSlot_TimeSlotID  NUMBER(10),
    ActivityDescription  NVARCHAR2(500),
    CONSTRAINT pk_activity PRIMARY KEY (ActivityID),
    CONSTRAINT fk_activity_event
        FOREIGN KEY (Event_EventID)       REFERENCES Event (EventID),
    CONSTRAINT fk_activity_room
        FOREIGN KEY (Room_RoomID)         REFERENCES Room (RoomID),
    CONSTRAINT fk_activity_category
        FOREIGN KEY (Category_CategoryID) REFERENCES Category (CategoryID),
    CONSTRAINT fk_activity_timeslot
        FOREIGN KEY (TimeSlot_TimeSlotID) REFERENCES TimeSlot (TimeSlotID)
);

CREATE TABLE Sponsor (
    SponsorID     NUMBER(10)    NOT NULL,
    SponsorName   VARCHAR2(100),
    Budget        NUMBER,
    Event_EventID NUMBER(10),
    CONSTRAINT pk_sponsor PRIMARY KEY (SponsorID),
    CONSTRAINT fk_sponsor_event
        FOREIGN KEY (Event_EventID) REFERENCES Event (EventID)
);

CREATE TABLE Register (
    RegistrationID       NUMBER(10)  NOT NULL,
    Users_UserID         NUMBER(10),
    Activity_ActivityID  NUMBER,
    RegistrationDate     DATE,
    CONSTRAINT pk_register PRIMARY KEY (RegistrationID),
    CONSTRAINT fk_register_users
        FOREIGN KEY (Users_UserID)        REFERENCES Users (UserID),
    CONSTRAINT fk_register_activity
        FOREIGN KEY (Activity_ActivityID) REFERENCES Activity (ActivityID)
);

CREATE TABLE Attendance (
    AttendanceID            NUMBER     NOT NULL,
    CheckInTime             DATE,
    Register_RegistrationID NUMBER(10),
    CONSTRAINT pk_attendance PRIMARY KEY (AttendanceID),
    CONSTRAINT fk_attendance_register
        FOREIGN KEY (Register_RegistrationID) REFERENCES Register (RegistrationID)
);

CREATE TABLE Feedback (
    FeedbackID     NUMBER(10)   NOT NULL,
    Rating         NUMBER(1),
    Comments       CLOB,
    SubmissionTime DATE,
    Event_EventID  NUMBER(10),
    Users_UserID   NUMBER(10),
    CONSTRAINT pk_feedback PRIMARY KEY (FeedbackID),
    CONSTRAINT chk_feedback_rating CHECK (Rating BETWEEN 1 AND 5),
    CONSTRAINT fk_feedback_event
        FOREIGN KEY (Event_EventID) REFERENCES Event (EventID),
    CONSTRAINT fk_feedback_users
        FOREIGN KEY (Users_UserID)  REFERENCES Users (UserID)
);

-- ============================================================================
--  End of schema.sql
-- ============================================================================
