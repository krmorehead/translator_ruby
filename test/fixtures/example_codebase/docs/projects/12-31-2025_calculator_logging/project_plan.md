# Project Plan

**Goal**: Add logging to Calculator

## Milestone 1: Set Up Logging Framework

Initialize logging infrastructure

### Step 1.1: Add logging library

**Intent**: Enable logging functionality

**Details**:
- Install logging package
- Configure log levels (debug, info, error)
- Set up log file output directory

**Tests**:
- Verify package is installed
- Test log output at different levels

---

### Step 1.2: Configure logger

**Intent**: Set log level and format

**Details**:
- Use environment variable for log level
- Format logs with timestamp and level
- Enable structured logging for machine readability

**Tests**:
- Verify log level changes with env var
- Check log format includes timestamp and level

---

### Step 1.3: Instrument calculator

**Intent**: Add log statements to key operations

**Details**:
- Add logging to add/subtract/multiply functions
- Log input values and results
- Use console.log with timestamps

**Tests**:
- Verify log output for 5+3=8
- Check error log for invalid inputs

---

### Step 1.4: Verify logs

**Intent**: Confirm logging works as expected

**Details**:
- Check log levels are set correctly in config
- Ensure logs are written to the correct file path

**Tests**:
- Test info, warning, error logs are generated
- Verify log file exists and has content

## Milestone 2: Instrument Core Functions

Add logs to basic operations

### Step 2.1: Add Log File Creation

**Intent**: Create log file on startup

**Details**:
- Create log directory if not exists
- Generate timestamped log file name
- Open file for writing

**Tests**:
- Verify log directory exists after startup
- Check log file has correct timestamp format

---

### Step 2.2: Log Inputs

**Intent**: Record all calculator inputs

**Details**:
- Create input log file in JSON format
- Store timestamp with each entry
- Log every user input operation

**Tests**:
- Verify log file is created on first input
- Test log contains correct input values and timestamps

---

### Step 2.3: Log Results

**Intent**: Record all calculation results

**Details**:
- Store results in database with timestamp
- Include input parameters and output
- Support result retrieval by ID

**Tests**:
- Verify data is persisted after restart
- Confirm result contains all parameters

---

### Step 2.4: Add Error Logging

**Intent**: Capture error conditions

**Details**:
- Create error logging module
- Log errors to file with timestamp
- Include error type and message

**Tests**:
- Verify error is logged when exception thrown
- Check log file contains correct timestamp

## Milestone 3: Implement Log Levels

Support different verbosity levels

### Step 3.1: Create log level enum

**Intent**: Define severity levels for logs

**Details**:
- Levels: Debug, Info, Warning, Error, Critical
- Add numeric values 1-5 for ordering
- Implement string conversion for each level

**Tests**:
- Verify numeric values match level order
- Check string conversion returns correct names

---

### Step 3.2: Add logger interface

**Intent**: Standardize logging across components

**Details**:
- Define interface with log, error, warn methods
- Ensure consistent message formatting
- Allow different implementations

**Tests**:
- Verify all methods exist and have correct signatures
- Test message formatting with sample inputs

---

### Step 3.3: Implement debug logging

**Intent**: Capture detailed operational data

**Details**:
- Add log statements to critical paths
- Use structured format with timestamps

**Tests**:
- Verify logs capture errors
- Check log format compliance

---

### Step 3.4: Implement error logging

**Intent**: Track exceptional conditions

**Details**:
- Log errors to file with timestamp and stack trace
- Include error severity levels (info, warning, error)

**Tests**:
- Verify error log file is created and populated with errors
- Check log entries contain correct severity levels and timestamps

## Milestone 4: Add Log Persistence

Store logs to file system

### Step 4.1: Create Log Model

**Intent**: Define data structure for storing logs

**Details**:
- Add log_id, timestamp, level, message fields
- Support JSON serialization/deserialization
- Include error code and stack trace fields

**Tests**:
- Validate required fields are not null
- Test JSON round-trip preserves data

---

### Step 4.2: Add Logging DB

**Intent**: Implement database for storing logs

**Details**:
- Create schema for logs table
- Add timestamps and error codes
- Support log levels (info/warning/error)

**Tests**:
- Verify log entry insertion
- Test query for specific log level

---

### Step 4.3: Persist Logs

**Intent**: Save logs after each operation

**Details**:
- Create log table with timestamp, level, message
- Add database connection for logging
- Write log after each operation

**Tests**:
- Verify log entry in DB after operation
- Check log table creation
