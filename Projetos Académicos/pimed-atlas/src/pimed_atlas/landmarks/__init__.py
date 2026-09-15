"""Landmarks and surface contacts for the public PIMED reconstruction.

This module is a new implementation derived from the intent of João Santos's
individual contribution to the original academic project.  It contains no
dataset identifiers, private medical data, GUI state or implicit anatomy.
"""

from pimed_atlas.core import ImageGeometry

from .components import analyse_landmarks, extract_label_components
from .contacts import analyse_surface_contacts
from .geometry import (
    angle_at_point_degrees,
    angle_between_vectors_degrees,
    axis_separation_mm,
    distance_mm,
)
from .laterality import LateralityConvention, assign_laterality
from .models import (
    AnalysisWarning,
    ComponentSurfacePair,
    ContactAnalysis,
    LabelAnalysis,
    LabelSpec,
    LandmarkAnalysis,
    LandmarkComponent,
    LateralityAssignment,
    LateralityResult,
)

__all__ = [
    "AnalysisWarning",
    "ComponentSurfacePair",
    "ContactAnalysis",
    "ImageGeometry",
    "LabelAnalysis",
    "LabelSpec",
    "LandmarkAnalysis",
    "LandmarkComponent",
    "LateralityAssignment",
    "LateralityConvention",
    "LateralityResult",
    "analyse_landmarks",
    "analyse_surface_contacts",
    "angle_at_point_degrees",
    "angle_between_vectors_degrees",
    "assign_laterality",
    "axis_separation_mm",
    "distance_mm",
    "extract_label_components",
]
