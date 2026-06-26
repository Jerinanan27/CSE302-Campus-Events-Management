-- ============================================================================
--  Campus Events Management System  —  Reporting & Analytics Queries
--
--  Each query below backs a report or chart page in the APEX application.
--  Bind variables (:P77_EVENT_NAME, :APP_USER_ID) are APEX page/item bindings.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  [Aggregate report]  Registrations per activity
--  Page: Registration Per Activity Report
-- ---------------------------------------------------------------------------
SELECT a.ActivityID,
       a.ActivityName,
       COUNT(r.RegistrationID) AS total_registrations
  FROM Activity a
  LEFT JOIN Register r
         ON r.Activity_ActivityID = a.ActivityID
 GROUP BY a.ActivityID, a.ActivityName
 ORDER BY total_registrations DESC;


-- ---------------------------------------------------------------------------
--  [Multi-table join]  User event history (past events attended)
--  Page: My Profile  →  Event History
-- ---------------------------------------------------------------------------
SELECT u.Username,
       e.Title          AS event_title,
       e.Start_Date,
       e.End_Date,
       at.CheckInTime
  FROM Users u
  JOIN Register   r  ON r.Users_UserID            = u.UserID
  JOIN Activity   a  ON a.ActivityID              = r.Activity_ActivityID
  JOIN Event      e  ON e.EventID                 = a.Event_EventID
  JOIN Attendance at ON at.Register_RegistrationID = r.RegistrationID
 WHERE u.UserID = :APP_USER_ID
 ORDER BY e.Start_Date DESC;


-- ---------------------------------------------------------------------------
--  [Parameterized report]  Activities filtered by a given event name
--  Page: Parameterized Report  (input item :P77_EVENT_NAME)
-- ---------------------------------------------------------------------------
SELECT a.ActivityID,
       a.ActivityName,
       a.Fee,
       a.ActivityDay,
       a.ActivityDescription
  FROM Activity a
  JOIN Event e ON e.EventID = a.Event_EventID
 WHERE e.Title = :P77_EVENT_NAME;


-- ---------------------------------------------------------------------------
--  [Chart]  Average rating per event
--  Page: Average Rating Per Event  (bar chart)
-- ---------------------------------------------------------------------------
SELECT e.Title,
       ROUND(AVG(f.Rating), 2) AS avg_rating,
       COUNT(f.FeedbackID)     AS n_responses
  FROM Event e
  JOIN Feedback f ON f.Event_EventID = e.EventID
 GROUP BY e.Title
 ORDER BY avg_rating DESC;


-- ---------------------------------------------------------------------------
--  [Chart]  Participants per event  (distinct registrants)
--  Page: Participants Per Event  (bar chart)
-- ---------------------------------------------------------------------------
SELECT e.Title,
       COUNT(DISTINCT r.Users_UserID) AS participants
  FROM Event e
  JOIN Activity a ON a.Event_EventID        = e.EventID
  JOIN Register r ON r.Activity_ActivityID  = a.ActivityID
 GROUP BY e.Title
 ORDER BY participants DESC;


-- ---------------------------------------------------------------------------
--  [Chart]  Number of events (activities) per room
--  Page: Number of Events Per Room  (line chart)
-- ---------------------------------------------------------------------------
SELECT rm.RoomName,
       COUNT(a.ActivityID) AS events_in_room
  FROM Room rm
  LEFT JOIN Activity a ON a.Room_RoomID = rm.RoomID
 GROUP BY rm.RoomName
 ORDER BY events_in_room DESC;


-- ---------------------------------------------------------------------------
--  [Chart]  User registrations over time (by month)
--  Page: User Registrations Over Time  (column chart)
-- ---------------------------------------------------------------------------
SELECT TO_CHAR(r.RegistrationDate, 'Month') AS reg_month,
       COUNT(*)                             AS registered_users
  FROM Register r
 GROUP BY TO_CHAR(r.RegistrationDate, 'Month'),
          EXTRACT(MONTH FROM r.RegistrationDate)
 ORDER BY EXTRACT(MONTH FROM r.RegistrationDate);


-- ---------------------------------------------------------------------------
--  [Chart]  Event duration (days) per event
--  Page: Event Duration  (line chart)
-- ---------------------------------------------------------------------------
SELECT e.Title,
       (e.End_Date - e.Start_Date) AS duration_days
  FROM Event e
 ORDER BY duration_days DESC;


-- ---------------------------------------------------------------------------
--  [Home page]  Upcoming events
-- ---------------------------------------------------------------------------
SELECT e.EventID,
       e.Title,
       e.Start_Date,
       e.End_Date
  FROM Event e
 WHERE e.Start_Date >= SYSDATE
 ORDER BY e.Start_Date ASC;

-- ============================================================================
--  End of reports.sql
-- ============================================================================
