"""
equipment_schemas.py — Canonical per-type JSON schemas for detected equipment.

This is the SINGLE SOURCE OF TRUTH for what spec fields are expected per
equipment category. It is consumed by:
  - frame_detector.py  (vision prompt knows what fields to look for)
  - spec_service.py    (builds the Gemini extraction prompt from this schema)
  - API routers        (guarantees consistent JSON shape to the Flutter app)
"""

from typing import Any, List, Optional
from pydantic import BaseModel, Field

# ── Pydantic Spec Schemas ─────────────────────────────────────────────────────

class AirConditionerSpecs(BaseModel):
    capacity_btu: Optional[int] = Field(None, description="Capacity in BTU, e.g. 9000, 12000, 18000, 24000")
    technology: Optional[str] = Field(None, description="Inverter or Non-Inverter")
    mode: Optional[str] = Field(None, description="Chaud & Froid, Froid Only, or Chaud Only")
    energy_class: Optional[str] = Field(None, description="A+++, A++, A+, A, B, C, etc.")
    refrigerant: Optional[str] = Field(None, description="R32, R410A, or R22")
    smart_wifi: Optional[bool] = Field(None, description="True if smart WiFi is supported, False otherwise")
    noise_level_db: Optional[int] = Field(None, description="Noise level in dB")
    power_consumption_w: Optional[int] = Field(None, description="Power consumption in Watts")
    annual_energy_consumption_kwh: Optional[float] = Field(None, description="Annual energy consumption in kWh")
    dimensions: Optional[str] = Field(None, description="HxWxD in cm")
    warranty_years: Optional[int] = Field(None, description="Warranty in years")

class RefrigeratorSpecs(BaseModel):
    capacity_liters: Optional[int] = Field(None, description="Total capacity in liters")
    energy_class: Optional[str] = Field(None, description="Energy class, e.g. A+++, A++, A+, A")
    refrigerant: Optional[str] = Field(None, description="Refrigerant gas used, e.g. R600a, R134a")
    no_frost: Optional[bool] = Field(None, description="True if no-frost, False otherwise")
    inverter: Optional[bool] = Field(None, description="True if inverter compressor, False otherwise")
    dimensions: Optional[str] = Field(None, description="HxWxD in cm")
    weight_kg: Optional[float] = Field(None, description="Weight in kg")
    noise_level_db: Optional[int] = Field(None, description="Noise level in dB")
    power_consumption_w: Optional[int] = Field(None, description="Power consumption in Watts")
    annual_energy_consumption_kwh: Optional[float] = Field(None, description="Annual energy consumption in kWh")
    warranty_years: Optional[int] = Field(None, description="Warranty in years")

class MicrowaveSpecs(BaseModel):
    power_watts: Optional[int] = Field(None, description="Microwave power in Watts")
    annual_energy_consumption_kwh: Optional[float] = Field(None, description="Annual energy consumption in kWh")
    capacity_liters: Optional[int] = Field(None, description="Capacity in liters")
    functions: Optional[List[str]] = Field(None, description="List of functions/modes, e.g. ['Grill', 'Defrost',""'Convection']")
    turntable_diameter_cm: Optional[int] = Field(None, description="Turntable plate diameter in cm")
    control_type: Optional[str] = Field(None, description="Digital, Analog, or Touch")
    dimensions: Optional[str] = Field(None, description="HxWxD in cm")
    weight_kg: Optional[float] = Field(None, description="Weight in kg")
    warranty_years: Optional[int] = Field(None, description="Warranty in years")

class LaptopSpecs(BaseModel):
    cpu: Optional[str] = Field(None, description="Processor model name, e.g. Intel Core i7-12700H")
    ram_gb: Optional[int] = Field(None, description="RAM in GB")
    storage: Optional[str] = Field(None, description="Storage capacity and type, e.g. 512GB SSD")
    display_inches: Optional[float] = Field(None, description="Screen size in inches")
    display_resolution: Optional[str] = Field(None, description="Screen resolution, e.g. 1920x1080")
    gpu: Optional[str] = Field(None, description="Graphics card model, e.g. NVIDIA RTX 3060")
    battery_wh: Optional[float] = Field(None, description="Battery capacity in Wh")
    power_supply_w: Optional[int] = Field(None, description="Power supply charger in Watts")
    os: Optional[str] = Field(None, description="Operating system installed")
    weight_kg: Optional[float] = Field(None, description="Weight in kg")
    warranty_years: Optional[int] = Field(None, description="Warranty in years")


class MonitorSpecs(BaseModel):
    screen_size_inches: Optional[float] = Field(None, description="Screen size in inches, e.g. 23.8, 27, 32")
    resolution: Optional[str] = Field(None, description="Display resolution, e.g. 1920x1080, 2560x1440, 3840x2160")
    panel_type: Optional[str] = Field(None, description="Panel technology, e.g. IPS, VA, TN, OLED")
    refresh_rate_hz: Optional[int] = Field(None, description="Refresh rate in Hz, e.g. 60, 75, 144, 240")
    response_time_ms: Optional[float] = Field(None, description="Response time in milliseconds, e.g. 1, 4, 5")
    aspect_ratio: Optional[str] = Field(None, description="Aspect ratio, e.g. 16:9, 21:9, 32:9")
    brightness_cdm2: Optional[int] = Field(None, description="Brightness in cd/m², e.g. 250, 300, 350")
    contrast_ratio: Optional[str] = Field(None, description="Contrast ratio, e.g. 1000:1, 3000:1")
    ports: Optional[List[str]] = Field(None, description="Available input/output ports, e.g. ['HDMI', 'DisplayPort', 'USB-C']")
    power_consumption_w: Optional[int] = Field(None, description="Power consumption in Watts")
    warranty_years: Optional[int] = Field(None, description="Warranty in years")


# ── Pydantic Envelopes ────────────────────────────────────────────────────────

class AirConditionerEnvelope(BaseModel):
    brand: str
    model: str
    equipment_category: str = "airconditioner"
    verified: bool
    source_quality: str
    specs: AirConditionerSpecs
    fields_found: int
    summary: str

class RefrigeratorEnvelope(BaseModel):
    brand: str
    model: str
    equipment_category: str = "refrigerator"
    verified: bool
    source_quality: str
    specs: RefrigeratorSpecs
    fields_found: int
    summary: str

class MicrowaveEnvelope(BaseModel):
    brand: str
    model: str
    equipment_category: str = "microwave"
    verified: bool
    source_quality: str
    specs: MicrowaveSpecs
    fields_found: int
    summary: str

class LaptopEnvelope(BaseModel):
    brand: str
    model: str
    equipment_category: str = "laptop"
    verified: bool
    source_quality: str
    specs: LaptopSpecs
    fields_found: int
    summary: str


class MonitorEnvelope(BaseModel):
    brand: str
    model: str
    equipment_category: str = "monitor"
    verified: bool
    source_quality: str
    specs: MonitorSpecs
    fields_found: int
    summary: str

class AirConditionerExtraction(BaseModel):
    exact_model_reference: str = Field(description="The exact model name and reference found (e.g. Lenovo Ideapad3 UK, or Samsung AR12TX)")
    specs: AirConditionerSpecs = Field(description="Technical specifications of the air conditioner")
    summary: str = Field(description="One factual sentence describing the product based only on verified data")

class RefrigeratorExtraction(BaseModel):
    exact_model_reference: str = Field(description="The exact model name and reference found (e.g. Lenovo Ideapad3 UK, or Samsung AR12TX)")
    specs: RefrigeratorSpecs = Field(description="Technical specifications of the refrigerator")
    summary: str = Field(description="One factual sentence describing the product based only on verified data")

class MicrowaveExtraction(BaseModel):
    exact_model_reference: str = Field(description="The exact model name and reference found (e.g. Lenovo Ideapad3 UK, or Samsung AR12TX)")
    specs: MicrowaveSpecs = Field(description="Technical specifications of the microwave")
    summary: str = Field(description="One factual sentence describing the product based only on verified data")

class LaptopExtraction(BaseModel):
    exact_model_reference: str = Field(description="The exact model name and reference found (e.g. Lenovo Ideapad3 UK, or Samsung AR12TX)")
    specs: LaptopSpecs = Field(description="Technical specifications of the laptop")
    summary: str = Field(description="One factual sentence describing the product based only on verified data")


class MonitorExtraction(BaseModel):
    exact_model_reference: str = Field(description="The exact model name and reference found (e.g. Lenovo Ideapad3 UK, or Dell U2419H)")
    specs: MonitorSpecs = Field(description="Technical specifications of the monitor")
    summary: str = Field(description="One factual sentence describing the product based only on verified data")

# Schema classes lookup
SPECS_SCHEMAS = {
    "airconditioner": AirConditionerSpecs,
    "refrigerator": RefrigeratorSpecs,
    "microwave": MicrowaveSpecs,
    "laptop": LaptopSpecs,
    "monitor": MonitorSpecs,
}

# Extraction classes lookup
SPECS_EXTRACTIONS = {
    "airconditioner": AirConditionerExtraction,
    "refrigerator": RefrigeratorExtraction,
    "microwave": MicrowaveExtraction,
    "laptop": LaptopExtraction,
    "monitor": MonitorExtraction,
}

# Envelope classes lookup
SPECS_ENVELOPES = {
    "airconditioner": AirConditionerEnvelope,
    "refrigerator": RefrigeratorEnvelope,
    "microwave": MicrowaveEnvelope,
    "laptop": LaptopEnvelope,
    "monitor": MonitorEnvelope,
}

# ── Canonical schemas ─────────────────────────────────────────────────────────
# All values are None → sentinel meaning "not yet populated".
# The spec service will fill them in and leave nulls for fields it cannot find.

EQUIPMENT_SCHEMAS: dict[str, dict[str, Any]] = {

    "airconditioner": {
        "capacity_btu":      None,   # int   e.g. 12000
        "technology":        None,   # str   "Inverter" | "Non-Inverter"
        "mode":              None,   # str   "Chaud & Froid" | "Froid Only" | "Chaud Only"
        "energy_class":      None,   # str   "A+++" | "A++" | "A+" | "A" | "B" | ...
        "refrigerant":       None,   # str   "R32" | "R410A" | "R22"
        "smart_wifi":        None,   # bool  True | False
        "noise_level_db":    None,   # int   e.g. 21
        "power_consumption_w": None, # int   e.g. 1500
        "annual_energy_consumption_kwh": None, # float e.g. 250.5
        "dimensions":        None,   # str   "HxWxD cm"
        "warranty_years":    None,   # int   e.g. 3
    },

    "refrigerator": {
        "capacity_liters":   None,   # int   e.g. 380
        "energy_class":      None,   # str   "A+++" etc.
        "refrigerant":       None,   # str   "R600a" | "R134a"
        "no_frost":          None,   # bool  True | False
        "inverter":          None,   # bool  True | False
        "dimensions":        None,   # str   "HxWxD cm"
        "weight_kg":         None,   # float e.g. 68.0
        "noise_level_db":    None,   # int   e.g. 39
        "power_consumption_w": None, # int   e.g. 150
        "annual_energy_consumption_kwh": None, # float e.g. 300.0
        "warranty_years":    None,   # int   e.g. 2
    },

    "microwave": {
        "power_watts":            None,   # int   e.g. 1000
        "annual_energy_consumption_kwh": None, # float e.g. 150.0
        "capacity_liters":        None,   # int   e.g. 25
        "functions":              None,   # list[str]  ["Grill", "Convection", "Defrost"]
        "turntable_diameter_cm":  None,   # int   e.g. 26
        "control_type":           None,   # str   "Digital" | "Analog" | "Touch"
        "dimensions":             None,   # str
        "weight_kg":              None,   # float
        "warranty_years":         None,   # int
    },

    "laptop": {
        "cpu":               None,   # str   "Intel Core i7-12700H"
        "ram_gb":            None,   # int   e.g. 16
        "storage":           None,   # str   "512GB SSD" | "1TB HDD"
        "display_inches":    None,   # float e.g. 15.6
        "display_resolution":None,   # str   "1920x1080" | "2560x1440"
        "gpu":               None,   # str   "NVIDIA RTX 3060" | "Intel Iris Xe"
        "battery_wh":        None,   # float e.g. 72.0
        "power_supply_w":    None,   # int   e.g. 65
        "os":                None,   # str   "Windows 11" | "FreeDOS"
        "weight_kg":         None,   # float e.g. 2.3
        "warranty_years":    None,   # int
    },

    "monitor": {
        "screen_size_inches":  None,   # float e.g. 23.8
        "resolution":          None,   # str   "1920x1080"
        "panel_type":          None,   # str   "IPS" | "VA" | ...
        "refresh_rate_hz":     None,   # int   e.g. 60
        "response_time_ms":    None,   # float e.g. 4.0
        "aspect_ratio":        None,   # str   "16:9"
        "brightness_cdm2":     None,   # int   e.g. 250
        "contrast_ratio":      None,   # str   "1000:1"
        "ports":               None,   # list[str] ["HDMI", "DisplayPort"]
        "power_consumption_w": None,   # int   e.g. 17
        "warranty_years":      None,   # int
    },
}

# ── Aliases for label normalisation (Roboflow / YOLOv5 class → schema key) ────
LABEL_TO_CATEGORY: dict[str, str] = {
    # Roboflow / YOLOv5 raw labels
    "airconditioner": "airconditioner",
    "air conditioner": "airconditioner",
    "air_conditioner": "airconditioner",
    "ac": "airconditioner",
    "split": "airconditioner",
    "climatiseur": "airconditioner",
    "refrigerator": "refrigerator",
    "fridge": "refrigerator",
    "réfrigérateur": "refrigerator",
    "refrigerateur": "refrigerator",
    "microwave": "microwave",
    "oven": "microwave",
    "micro-onde": "microwave",
    "micro_onde": "microwave",
    "laptop": "laptop",
    "ordinateur": "laptop",
    "computer": "laptop",
    "notebook": "laptop",
    "monitor": "monitor",
    "screen": "monitor",
    "display": "monitor",
    "ecran": "monitor",
    "écran": "monitor",
}

# ── Human-readable labels for prompt injection ─────────────────────────────────
CATEGORY_LABELS: dict[str, str] = {
    "airconditioner": "Air Conditioner / Split Unit",
    "refrigerator":   "Refrigerator / Fridge",
    "microwave":      "Microwave Oven",
    "laptop":         "Laptop / Notebook Computer",
    "monitor":        "Computer Monitor / Display Screen",
}


def get_schema(equipment_type: str) -> dict[str, Any]:
    """
    Return a fresh copy of the canonical schema for the given equipment type.
    Falls back to the most generic schema if type is unrecognised.
    """
    import copy
    category = LABEL_TO_CATEGORY.get(equipment_type.lower().strip(), None)
    return copy.deepcopy(EQUIPMENT_SCHEMAS.get(category or equipment_type, {}))


def normalize_category(raw_label: str) -> str:
    """Normalise any raw equipment label to a canonical category key."""
    return LABEL_TO_CATEGORY.get(raw_label.lower().strip(), raw_label.lower().strip())


def schema_as_prompt_fields(equipment_type: str) -> str:
    """
    Serialise the schema for a given type into a JSON-like prompt snippet
    that Gemini can fill in.  All values are replaced with descriptive hints.
    """
    hints: dict[str, dict[str, str]] = {
        "airconditioner": {
            "capacity_btu":   "integer — e.g. 9000, 12000, 18000, 24000",
            "technology":     "\"Inverter\" or \"Non-Inverter\"",
            "mode":           "\"Chaud & Froid\" | \"Froid Only\" | \"Chaud Only\"",
            "energy_class":   "\"A+++\" | \"A++\" | \"A+\" | \"A\" | \"B\" | \"C\" or null",
            "refrigerant":    "\"R32\" | \"R410A\" | \"R22\" or null",
            "smart_wifi":     "true or false",
            "noise_level_db": "integer dB",
            "power_consumption_w": "integer Watts",
            "annual_energy_consumption_kwh": "float kWh",
            "dimensions":     "\"HxWxD cm\" string e.g. \"29x79x19 cm\"",
            "warranty_years": "integer or null",
        },
        "refrigerator": {
            "capacity_liters":"integer liters or null",
            "energy_class":   "\"A+++\" | \"A++\" | \"A+\" | \"A\" | \"B\" | \"C\" or null",
            "refrigerant":    "\"R600a\" | \"R134a\" or null",
            "no_frost":       "true or false",
            "inverter":       "true or false",
            "dimensions":     "\"HxWxD cm\" string e.g. \"185x60x65 cm\" or null",
            "weight_kg":      "float kg",
            "noise_level_db": "integer dB",
            "power_consumption_w": "integer Watts",
            "annual_energy_consumption_kwh": "float kWh",
            "warranty_years": "integer",
        },
        "microwave": {
            "power_watts":           "integer watts",
            "annual_energy_consumption_kwh": "float kWh",
            "capacity_liters":       "integer liters",
            "functions":             "array of strings e.g. [\"Grill\", \"Defrost\"] or null",
            "turntable_diameter_cm": "integer cm or null",
            "control_type":          "\"Digital\" | \"Analog\" | \"Touch\" or null",
            "dimensions":            "\"HxWxD cm\" string or null",
            "weight_kg":             "float kg or null",
            "warranty_years":        "integer or null",
        },
        "laptop": {
            "cpu":               "full CPU name e.g. \"Intel Core i7-12700H\" or null",
            "ram_gb":            "integer GB or null",
            "storage":           "string e.g. \"512GB SSD\" or null",
            "display_inches":    "float e.g. 15.6 or null",
            "display_resolution":"string e.g. \"1920x1080\" or null",
            "gpu":               "GPU name string",
            "battery_wh":        "float Wh",
            "power_supply_w":    "integer Watts",
            "os":                "\"Windows 11\" | \"FreeDOS\" | \"Linux\"",
            "weight_kg":         "float kg or null",
            "warranty_years":    "integer or null",
        },
        "monitor": {
            "screen_size_inches":  "float screen size in inches, e.g. 23.8 or 27",
            "resolution":          "string resolution, e.g. \"1920x1080\" or \"2560x1440\"",
            "panel_type":          "\"IPS\" | \"VA\" | \"TN\" | \"OLED\" or null",
            "refresh_rate_hz":     "integer refresh rate, e.g. 60 or 144",
            "response_time_ms":    "float response time in ms, e.g. 4.0 or 1.0",
            "aspect_ratio":        "string aspect ratio, e.g. \"16:9\" or \"21:9\"",
            "brightness_cdm2":     "integer brightness in cd/m², e.g. 250 or 300",
            "contrast_ratio":      "string contrast ratio, e.g. \"1000:1\" or \"3000:1\"",
            "ports":               "array of strings, e.g. [\"HDMI\", \"DisplayPort\"] or null",
            "power_consumption_w": "integer Watts",
            "warranty_years":      "integer or null",
        },
    }
    category = normalize_category(equipment_type)
    fields = hints.get(category, {})
    if not fields:
        return "{}"
    import json
    return json.dumps(fields, ensure_ascii=False, indent=2)
