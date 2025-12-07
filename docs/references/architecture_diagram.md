# Architecture Diagram

## System Overview

Translator Ruby is a Rails 8 API-only application that provides translation services using LLM (Large Language Model) backends.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Client                                    │
│                    (REST API Consumer)                              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Rails API Layer                             │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    ApplicationController                       │  │
│  │                   (ActionController::API)                      │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                  │                                  │
│         ┌────────────────────────┼────────────────────────┐         │
│         ▼                        ▼                        ▼         │
│  ┌─────────────┐     ┌───────────────────────┐     ┌──────────┐    │
│  │ HelloController│  │TranslationController  │     │  Future  │    │
│  │   (Health)   │     │  (translate, text)   │     │Controllers│   │
│  └─────────────┘     └───────────────────────┘     └──────────┘    │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Service Layer                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    TranslationService                         │  │
│  │  - Document parsing (JSON/YAML)                               │  │
│  │  - LLM client management                                      │  │
│  │  - Translation orchestration                                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                  │                                  │
│                                  ▼                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                  TranslationTreeService                       │  │
│  │  - Tree traversal for nested documents                        │  │
│  │  - Leaf node identification                                   │  │
│  │  - Context path building                                      │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Model Layer                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   TranslationContext                          │  │
│  │  - text, target_lang, source_lang                             │  │
│  │  - context, model_type, formality                             │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       External Services                             │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    LLM Backend (OpenAI API)                   │  │
│  │  - Configurable via LLM_URL environment variable              │  │
│  │  - Supports structured JSON output                            │  │
│  │  - Model configurable via LLM_MODEL                           │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. Document Translation (`POST /api/v1/translate`)

```
Request → TranslationController#translate
       → TranslationService#translate_document
       → Parse input (JSON/YAML)
       → Convert to YAML for processing
       → TranslationTreeService#traverse
       → For each leaf node:
           → Create TranslationContext
           → TranslationService#translate_text
           → LLM API call
       → Convert to export format (JSON/YAML)
       → Response
```

### 2. Text Translation (`POST /api/v1/translate_text`)

```
Request → TranslationController#translate_text
       → Create TranslationContext
       → TranslationService#translate_text
       → LLM API call with structured output
       → Response
```

## Data Flow

```
┌────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Input        │     │   Processing     │     │   Output        │
├────────────────┤     ├──────────────────┤     ├─────────────────┤
│ JSON/YAML doc  │ ──▶ │ Parse & traverse │ ──▶ │ Translated doc  │
│ Plain text     │     │ Create contexts  │     │ JSON/YAML       │
│ Target lang    │     │ LLM translation  │     │                 │
│ Source lang    │     │ Preserve vars    │     │                 │
│ Formality      │     │ Protect terms    │     │                 │
└────────────────┘     └──────────────────┘     └─────────────────┘
```

## Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| TranslationController | HTTP request handling | `app/controllers/api/v1/` |
| TranslationService | Core translation logic | `app/services/` |
| TranslationTreeService | Document traversal | `app/services/` |
| TranslationContext | Translation parameters | `app/models/` |
| OpenAI Client | LLM communication | Via `openai` gem |

## Environment Dependencies

| Variable | Purpose | Default |
|----------|---------|---------|
| `LLM_URL` | LLM backend endpoint | Required |
| `LLM_MODEL` | Model to use | `qwen30b` |
| `API_KEY` | Authorization token | Required |
| `PORT` | Server port | `52020` |

## Database

- **PostgreSQL 16** for Rails internals (Cache, Queue, Cable)
- No application-level database tables currently
- TranslationContext is an in-memory model (PORO)

