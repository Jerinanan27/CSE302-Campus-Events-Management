-- ============================================================================
--  Campus Events Management System  —  Triggers (PL/SQL)
--  Run AFTER schema.sql
--
--  Two business rules enforced at the database layer:
--    1. trg_check_capacity   — block registration when an event is full
--    2. trg_set_event_status — auto-set event status from its end date
-- ============================================================================

-- ---------------------------------------------------------------------------
--  1. Capacity enforcement
--     Prevents a Register insert when the related event has already reached
--     its capacity. Raises ORA-20001, which surfaces in the APEX UI.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_check_capacity
BEFORE INSERT ON Register
FOR EACH ROW
DECLARE
    v_capacity      Event.Capacity%TYPE;
    v_current_count NUMBER;
    v_event_id      Event.EventID%TYPE;
BEGIN
    -- Resolve the event behind the activity being registered for
    SELECT a.Event_EventID
      INTO v_event_id
      FROM Activity a
     WHERE a.ActivityID = :NEW.Activity_ActivityID;

    -- Capacity declared for that event
    SELECT e.Capacity
      INTO v_capacity
      FROM Event e
     WHERE e.EventID = v_event_id;

    -- Current registrations across all activities of the event
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

-- ---------------------------------------------------------------------------
--  2. Auto event-status transition
--     Keeps Event.Status consistent with the calendar so reports and the
--     home page always reflect current state.
-- ---------------------------------------------------------------------------

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

-- ============================================================================
--  End of triggers.sql
-- ============================================================================
