# Project Plan

**Goal**: Add logging to Calculator

## Milestone 1: Design Logging System

Create logging architecture

### Step 1.1: Add log file

**Intent**: Create storage for logs

**Details**:
- Create log directory in /var/log/app
- Use rotating file handler for log files
- Set log file size limit to 10MB

**Tests**:
- Verify log directory is created on startup
- Test log rotation when file exceeds 10MB

---

### Step 1.2: Create logger interface

**Intent**: Define logging contract

**Details**:
- Specify log levels (debug, info, error)
- Define write method signature

**Tests**:
- Verify interface compiles
- Ensure all required methods exist

---

### Step 1.3: Implement file logger

**Intent**: Write logs to file

**Details**:
- Create log directory if not exists
- Format log messages with timestamp
- Write logs to file with rotation

**Tests**:
- Verify log file creation and content
- Test log rotation when file size exceeds limit

---

### Step 1.4: Add log levels

**Intent**: Support different severities

**Details**:
- Add debug, info, warn, error levels
- Map levels to numeric values (DEBUG=1 to ERROR=4)
- Ensure level determines message handling

**Tests**:
- Verify level conversion from string to number
- Test message routing based on level

## Milestone 2: Implement Logging

Add logging to calculator

### Step 2.1: Add Log File

**Intent**: Create log storage

**Details**:
- Create log directory in system temp folder
- Implement log rotation to keep 5 most recent files
- Format log entries with timestamp and severity level

**Tests**:
- Verify log file is created with correct permissions
- Test log rotation keeps only 5 files after 6th log is generated

---

### Step 2.2: Log Errors

**Intent**: Capture error events

**Details**:
- Create error logging system
- Log error details to file
- Include timestamp and error message

**Tests**:
- Verify error is written to log file
- Check log file contains correct timestamp

---

### Step 2.3: Log Inputs

**Intent**: Track user actions

**Details**:
- Record timestamp
- Capture input method (keyboard/touch)
- Store in database

**Tests**:
- Verify timestamps are unique
- Check input method validation

---

### Step 2.4: Log Results

**Intent**: Record calculation outcomes

**Details**:
- Create log entry with timestamp
- Store input values and result
- Format as JSON for readability

**Tests**:
- Verify log file contains correct timestamp
- Check JSON structure validity

## Milestone 3: Test Logging

Verify logging functionality

### Step 3.1: Create logger interface

**Intent**: Define logging contract for implementation

**Details**:
- Define methods: log(level, message), setLevel(level)
- Support levels: debug, info, warning, error
- Ensure thread-safe method access

**Tests**:
- Verify all level constants are available
- Test method throws on invalid level input

---

### Step 3.2: Implement console logger

**Intent**: Provide basic logging output to console

**Details**:
- Create logging module with debug/info/warn/error levels
- Format messages with timestamp and level prefix
- Enable log level filtering via configuration

**Tests**:
- Verify message appears in console with correct format
- Confirm only messages above configured level are shown

---

### Step 3.3: Add logging to calculator

**Intent**: Instrument calculator operations with logs

**Details**:
- Log input values and operation type before calculation
- Record result and execution time after calculation

**Tests**:
- Verify log entries contain operation type and values
- Confirm timestamp and duration are logged for each calculation

---

### Step 3.4: Verify log output

**Intent**: Confirm logging works with test cases

**Details**:
- Check log file format matches schema
- Validate log entries contain timestamps

**Tests**:
- Test empty log file returns no entries
- Test log rotation preserves oldest entries
