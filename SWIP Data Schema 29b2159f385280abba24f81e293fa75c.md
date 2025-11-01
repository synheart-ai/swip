# SWIP: Data Schema

Author: Bemnet Girma
Status: Draft
Category: Architecture
Last edited time: October 30, 2025 9:29 AM
Reviewers: Israel, Anwar Tuha

## 1. Context and Background

The SWIP application is designed to track and analyze **digital wellbeing** through a proprietary **SWIP score**, which integrates app usage sessions and biosignal data from wearable devices.

The system processes **anonymous user data** collected from two primary sources:

- **Device** — data collected from the client (watch or phone)
- **SDK** — data collected from the Apple HealthKit SDK

Emotions are classified in **real-time (every 3–5 minutes)** based on biosignals, and the resulting emotional state, physiological scores, and digital wellbeing scores (swip score) are stored (with user consent).

The architecture prioritizes a **privacy-first approach**:

- Data can either be stored locally on the device or in the cloud, depending on user consent.
- Users can provide multiple consent types (e.g., research, AI model training).
- Application and device-level failures are tracked to ensure reliability and data quality.

## 2. Decision

We decided to implement a **modular, star-schema-inspired data model** to separate different data entities (users, consents, sessions, biosignals, emotions, apps, and failures) while maintaining referential integrity across tables.

The design emphasizes:

- **Privacy and consent-based storage**
- **Device-level traceability**
- **Granular data linkage** between biosignals, emotions, and sessions
- **Extensibility** for future models and analytics

## 3. Data Schema Overview

### 3.1 Entities

### **dim_swip_users**

Stores unique, anonymous users of the SWIP app.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| user_id | uuid (PK) | Device | Unique user identifier |
| created_datetime | timestamp | Device | User creation timestamp |

### **dim_swip_users_consent**

Tracks user consents (e.g., research, model training).

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| user_id | uuid (FK → dim_swip_users.user_id) | Device | Associated user |
| type | string | Device | Consent category |
| created_datetime | timestamp | Device | Timestamp of consent |
| status | string | Device | Active or revoked status of consent |

### **dim_App_Session**

Represents each app session recorded by a device.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| app_session_id | uuid (PK) | Device | Unique session ID |
| user_id | string (FK → dim_swip_users.user_id) | Device | Associated user |
| device_id | uuid (FK → dim_devices.device_id) | Device | Device used |
| started_at | timestamp | Device | Session start |
| ended_at | timestamp | Device | Session end |
| app_id | uuid (FK → dim_app.app_id) | Device | Application identifier |
| data_on_cloud | boolean | Device | True if data stored in cloud |
| avg_swip_score | float | Device | Calculated average SWIP score per session |

### **dim_App_failure**

Captures application failures during a session.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| app_session_id | uuid (FK → dim_App_Session.app_session_id) | Device | Associated session |
| failure_name | string | Device | Error or failure type |
| created_datetime | timestamp | Device | Timestamp of failure |

### **dim_App_biosignals**

Stores time-series biosignal metrics captured from wearables via SDK.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| app_biosignal_id | uuid (PK) | Device | Unique biosignal record |
| app_session_id | uuid (FK → dim_App_Session.app_session_id) | Device | Associated session |
| timestamp | timestamp | SDK | Reading time |
| respiratory_rate | float | SDK | Nullable |
| hrv_sdnn | float | SDK | Nullable |
| heart_rate | float | SDK | Nullable |
| accelerometer | float | SDK | Nullable |
| temperature | float | SDK | Nullable |
| blood_oxygen_saturation | float | SDK | Nullable |
| ecg | float | SDK | Nullable |
| emg | float | SDK | Nullable |
| eda | float | SDK | Nullable |
| gyro | float | SDK | Nullable |
| ppg | float | SDK | Nullable |
| ibi | float | SDK | Nullable |

### **dim_emotions**

Stores emotion classification and model outputs from biosignal inference.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| app_biosignal_id | uuid (FK → dim_App_biosignals.app_biosignal_id) | Device | Associated biosignal |
| swip_score | float | Device | Overall SWIP score |
| phys_subscore | float | Device | Physiological subscore |
| emo_subscore | float | Device | Emotional subscore |
| confidence | float | Device | Model prediction confidence |
| dominant_emotion | string | Device | e.g., Calm, Stressed, Focused |
| model_id | string | Device | ML model version used |

### **dim_app**

Metadata about installed apps monitored in sessions.

| Column | Type | Source | Notes |
| --- | --- | --- | --- |
| app_id | string (PK) | Device | Unique app identifier |
| app_name | string | Device | App name |
| app_version | string | Device | Version |
| category | string | Device | App category |
| developer | string | Device | App developer |
| app_avg_swip_score | float | Device | Calculated average SWIP score across sessions |

### 3.2 Relationships

| Parent | → | Child | Relationship |
| --- | --- | --- | --- |
| dim_devices.device_id | → | dim_App_Session.device_id | Device used in session |
| dim_App_Session.app_session_id | → | dim_App_biosignals.app_session_id | Biosignals per session |
| dim_App_biosignals.app_biosignal_id | → | dim_emotions.app_biosignal_id | Emotion classification |
| dim_App_Session.app_id | → | dim_app.app_id | One time App session |
| dim_swip_users.user_id | → | dim_swip_users_consent.user_id | Consent linkage |
| dim_App_Session.app_session_id | ← | dim_App_failure.app_session_id | Failure tracking |

## 4. Rationale

- **Privacy First:** Data storage is conditional on explicit user consent. Local-only mode ensures compliance with privacy regulations.
- **Modularity:** Each dimension isolates logical entities (users, biosignals, emotions) for easier maintenance and scalability.
- **Traceability:** Session, device, and failure tracking enables full observability of app behavior.
- **Analytics-Ready:** The structure supports time-series analytics, emotional state prediction accuracy tracking, and aggregated SWIP score reporting.
- **Interoperability:** Integration with HealthKit SDK provides consistent biosignal metrics and standardization across devices.

## 5. Consequences

### Positive:

- High privacy compliance and data ownership transparency
- Scalable, analytical schema suitable for ML training and behavioral insights
- Enables per-user or global model improvement tracking
- Supports offline-first design

## 6. Alternatives Considered

- **Single-table design:** Rejected for lack of modularity and analytical scalability.
- **Event-based data model:** Considered, but star schema better supports temporal and statistical queries for wellbeing trends.

## 7. Future Considerations

- Federated learning pipeline using local-only training to preserve privacy

## 8. Decision Summary

| Aspect | Decision |
| --- | --- |
| Architecture Pattern | Modular Star Schema |
| Privacy Model | Consent-driven local/cloud hybrid |
| Data Sources | Device + SDK |
| Real-time Emotion Classification | Yes (3–5 min intervals) |
| Storage | PostgreSQL (cloud) / On-device (local) |
| Ownership | Anonymous User-based |
| Logging | Failures and session-level events |

## 10. Version History

| Version | Date | Author | Notes | ER Diagram |
| --- | --- | --- | --- | --- |
| 1.0 | 2025-10-29 | Bemnet Girma | Initial version of ADR for SWIP Data Schema | [https://app.eraser.io/workspace/Aj0KmZHFsZvOhFvQkke3](https://app.eraser.io/workspace/Aj0KmZHFsZvOhFvQkke3) |