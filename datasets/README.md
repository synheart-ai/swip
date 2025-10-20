# SWIP Datasets

This directory contains reference datasets and metadata for SWIP protocol validation and research.

## Status

**🚧 Planned** - Reference datasets are planned but not yet available.

## Planned Dataset Structure

```
datasets/
├── SWIP-WRD-1/           # Wellness Reference Dataset v1
│   ├── metadata.json     # Dataset metadata and schema
│   ├── samples/          # Sample data files
│   └── validation/       # Validation results
└── README.md             # This file
```

## Planned SWIP-WRD-1: Wellness Reference Dataset

### Overview
The SWIP Wellness Reference Dataset (WRD-1) will be a curated collection of anonymized HRV measurements and wellness assessments designed for:

- Protocol validation and testing
- Algorithm development and benchmarking
- Research and academic studies
- SDK testing and validation

### Planned Characteristics

- **Size**: 1,000+ anonymized sessions
- **Duration**: 5-60 minute sessions
- **Demographics**: Diverse age groups (18-65)
- **Conditions**: Various wellness states (baseline, stress, recovery, focus)
- **Format**: SWIP-compliant JSON format
- **Privacy**: Fully anonymized, no PII

### Planned Data Schema

```json
{
  "session": {
    "id": "session_uuid",
    "timestamp": "ISO8601_timestamp",
    "duration": 1800,
    "platform": "ios|android|flutter|react-native"
  },
  "participant": {
    "age_group": "18-25|26-35|36-45|46-55|56-65",
    "gender": "male|female|other|prefer_not_to_say",
    "fitness_level": "low|moderate|high"
  },
  "measurements": {
    "hrv": {
      "rmssd": 42.5,
      "sdnn": 38.2,
      "pnn50": 12.3,
      "frequency_domain": {
        "lf": 156.7,
        "hf": 89.3,
        "lf_hf_ratio": 1.76
      }
    },
    "wellness_metrics": {
      "coherence_index": 0.73,
      "stress_recovery_rate": 0.68,
      "delta_hrv": 0.15
    }
  },
  "context": {
    "activity": "baseline|stress|recovery|focus|exercise|meditation",
    "environment": "indoor|outdoor|office|home",
    "time_of_day": "morning|afternoon|evening|night"
  }
}
```

### Planned Usage Guidelines

1. **Research**: Use for academic research with proper citation
2. **Development**: Test SDK implementations and algorithms
3. **Validation**: Validate SWIP protocol compliance
4. **Benchmarking**: Compare algorithm performance

### Planned Access

- **Open Access**: Available under Creative Commons Attribution 4.0
- **Citation Required**: Proper attribution to Synheart Open Council
- **Commercial Use**: Allowed with attribution
- **Redistribution**: Permitted with original license

---

**Dataset Curator**: Israel Goytom  
**Organization**: Synheart Open Council (SOC)  
**License**: Creative Commons Attribution 4.0 International (Planned)
