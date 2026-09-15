from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

import numpy as np

from pimed_atlas.core import read_legacy_vtk

VTK_AVAILABLE = importlib.util.find_spec("vtkmodules") is not None


@unittest.skipUnless(VTK_AVAILABLE, "a dependência opcional VTK não está instalada")
class LegacyVtkIoTests(unittest.TestCase):
    def test_round_trip_preserves_array_origin_and_spacing(self):
        from vtkmodules.util.numpy_support import numpy_to_vtk
        from vtkmodules.vtkCommonDataModel import vtkImageData
        from vtkmodules.vtkIOLegacy import vtkStructuredPointsWriter

        data = np.arange(24, dtype=np.uint8).reshape((2, 3, 4))
        image = vtkImageData()
        image.SetDimensions(4, 3, 2)
        image.SetSpacing(0.5, 0.75, 1.25)
        image.SetOrigin(2.0, 3.0, 4.0)
        image.GetPointData().SetScalars(numpy_to_vtk(data.ravel(), deep=True))

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.vtk"
            writer = vtkStructuredPointsWriter()
            writer.SetFileName(str(path))
            writer.SetInputData(image)
            self.assertEqual(writer.Write(), 1)
            recovered = read_legacy_vtk(path, case_id="synthetic-vtk")

        np.testing.assert_array_equal(recovered.data_zyx, data)
        self.assertEqual(recovered.geometry.spacing_zyx, (1.25, 0.75, 0.5))
        self.assertEqual(recovered.geometry.origin_xyz_mm, (2.0, 3.0, 4.0))
        self.assertEqual(recovered.case_id, "synthetic-vtk")


if __name__ == "__main__":
    unittest.main()
