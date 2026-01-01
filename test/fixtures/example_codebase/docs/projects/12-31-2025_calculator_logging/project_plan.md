# Project Plan

**Goal**: Add logging to Calculator

## Milestone 1: Design Logging System

Define logging requirements and structure

### Step 1.1: Define log levels

**Intent**: Establish severity categories for log messages

**Details**:
- Create levels: debug, info, warning, error
- Assign numeric values 1-4 for severity
- Define JSON schema for log records

**Tests**:
- Verify level enums match schema
- Test severity ordering in output

---

### Step 1.2: Create log format

**Intent**: Standardize log message structure

**Details**:
- Use JSON format
- Include timestamp, log level, message
- Add context fields for metadata

**Tests**:
- Validate JSON schema compliance
- Check required fields presence

---

### Step 1.3: Determine output destinations

**Intent**: Specify where logs will be written

**Details**:
- Logs will be written to stdout
- Logs will be written to a file when --log-file flag is provided
- Log file path will be determined by --log-file argument

**Tests**:
- Verify logs are printed to console when no log file is specified
- Check log file is created and written to when --log-file is provided

---

### Step 1.4: Plan log rotation

**Intent**: Implement log file management strategy

**Details**:
- Set max file size of 10MB
- Keep 5 most recent log files

**Tests**:
- Verify log rotation triggers after 10MB
- Confirm old logs are deleted after 5 files are kept

## Milestone 2: Implement Logging

Add logging to core components

### Step 2.1: Add Log Interface

**Intent**: Define logging contract

**Details**:
- Create interface with log methods (info, error, debug)
- Include severity levels and message formatting requirements
- Specify method signatures for consistency across implementations

**Tests**:
- Verify interface has all required methods
- Test implementation against interface contract

---

### Step 2.2: Create File Logger

**Intent**: Implement file-based logging

**Details**:
- Create log directory if not exists
- Format log entries with timestamp and level
- Append logs to file with rotation

**Tests**:
- Verify log file created in correct directory
- Check log entry format matches specification

---

### Step 2.3: Add Logging To Add

**Intent**: Track add operations

**Details**:
- Log input values before operation
- Log result after operation
- Use console.log for visibility

**Tests**:
- Verify inputs are logged correctly
- Check result is logged after operation

---

### Step 2.4: Add Logging To Subtract

**Intent**: Track subtract operations

**Details**:
- Log operation type, operands, and result
- Add log file rotation with 5MB size limit
- Use JSON format for structured logs

**Tests**:
- Verify log file grows with each subtraction
- Check log rotation creates new file when size limit reached

## Milestone 3: Test Logging

Validate logging functionality

### Step 3.1: Add log method

**Intent**: Create logging interface

**Details**:
- Define Log interface with write method
- Support multiple log levels (info, error, debug)

**Tests**:
- Verify log method writes to file
- Test different log levels are handled correctly

---

### Step 3.2: Mock logger

**Intent**: Enable test verification

**Details**:
- Create interface for logging functions
- Implement mock logger that captures log messages

**Tests**:
- Verify log messages are captured correctly
- Check that logger interface is properly implemented

---

### Step 3.3: Log operations

**Intent**: Track calculation events

**Details**:
- Add operation logging to calculator service
- Include timestamp and operation type in log entries
- Store logs in memory for 24 hours

**Tests**:
- Verify log contains correct operation type and timestamp
- Confirm logs expire after 24 hours

---

### Step 3.4: Verify logs

**Intent**: Confirm logging behavior

**Details**:
- Check log level configuration in config file
- Validate log output format matches schema

**Tests**:
- Test debug logs are written when level is set to debug
- Verify error logs include stack trace for exceptions
