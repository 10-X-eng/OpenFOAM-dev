"""Read cavity exports with VTK (or ParaView's pvpython), including field values."""
import argparse
import math
from pathlib import Path
import re

from vtkmodules.vtkIOLegacy import vtkDataSetReader
from vtkmodules.vtkCommonCore import vtkOutputWindow, vtkStringOutputWindow


def read_mesh(path):
    reader = vtkDataSetReader()
    errors = []
    reader.AddObserver("ErrorEvent", lambda obj, event: errors.append(event))
    reader.AddObserver("WarningEvent", lambda obj, event: errors.append(event))
    reader.SetFileName(str(path))
    reader.ReadAllScalarsOn()
    reader.ReadAllVectorsOn()
    reader.ReadAllFieldsOn()
    # Delegated readers can log an error without propagating it to the parent.
    previous = vtkOutputWindow.GetInstance()
    messages = vtkStringOutputWindow()
    vtkOutputWindow.SetInstance(messages)
    try:
        reader.Update()
    finally:
        vtkOutputWindow.SetInstance(previous)
    if errors or reader.GetErrorCode() or messages.GetOutput():
        raise AssertionError(f"VTK reader rejected {path}: {errors} {messages.GetOutput()}")
    mesh = reader.GetOutput()
    assert mesh.GetNumberOfCells() > 0, f"Empty cells: {path}"
    assert mesh.GetNumberOfPoints() > 0, f"Empty points: {path}"
    for i in range(mesh.GetNumberOfPoints()):
        assert all(math.isfinite(v) for v in mesh.GetPoint(i)), path
    for i in range(mesh.GetNumberOfCells()):
        ids = mesh.GetCell(i).GetPointIds()
        assert ids.GetNumberOfIds() > 0, path
        assert all(0 <= ids.GetId(j) < mesh.GetNumberOfPoints()
                   for j in range(ids.GetNumberOfIds())), path
    for data, count in ((mesh.GetPointData(), mesh.GetNumberOfPoints()),
                        (mesh.GetCellData(), mesh.GetNumberOfCells())):
        for i in range(data.GetNumberOfArrays()):
            array = data.GetArray(i)
            assert array is not None, path
            assert array.GetNumberOfTuples() == count, (path, array.GetName())
            for j in range(count):
                assert all(math.isfinite(v) for v in array.GetTuple(j)), path
    return mesh


def check_case(case, expected_format=None):
    files = sorted((case / "VTK").rglob("*.vtk"))
    assert len(files) >= 3, "Expected internal mesh and boundary exports"
    for path in files:
        if expected_format:
            with path.open('rb') as stream:
                stream.readline()
                stream.readline()
                assert stream.readline().strip().decode('ascii') == expected_format, (path, expected_format)
        mesh = read_mesh(path)
        if path.parent == case / "VTK":
            assert mesh.GetNumberOfCells() == 400, "Cavity cell count changed"
            assert mesh.GetNumberOfPoints() == 882, "Cavity point count changed"
            for got, expected in zip(mesh.GetBounds(), (0, .1, 0, .1, 0, .01)):
                assert math.isclose(got, expected, abs_tol=1e-7), mesh.GetBounds()
            for field, components in (("p", 1), ("U", 3)):
                source = (case / "0.5" / field).read_text()
                match = re.search(r"internalField\s+nonuniform\s+List<\w+>\s+(\d+)\s*\((.*?)\)\s*;", source, re.S)
                assert match, f"Cannot parse source field {field}"
                values = [float(v) for v in re.findall(r"[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?", match[2])]
                array = mesh.GetCellData().GetArray(field)
                assert array is not None, f"Missing exported field {field}"
                assert array.GetNumberOfComponents() == components, field
                assert len(values) == array.GetNumberOfTuples() * components, field
                for i, expected in enumerate(values):
                    got = array.GetComponent(i // components, i % components)
                    assert math.isclose(got, expected, rel_tol=2e-6, abs_tol=1e-7), (field, i, got, expected)
        print(f"PASS: VTK read {path.name}: {mesh.GetNumberOfCells()} cells, {mesh.GetNumberOfPoints()} points")
    print("PASS: exported pressure and velocity match the solver's final fields")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Cavity case directory, or one VTK file to check for corruption")
    parser.add_argument("--format", choices=("BINARY", "ASCII"))
    args = parser.parse_args()
    if args.path.is_file():
        read_mesh(args.path)
        print(f"PASS: VTK read {args.path}")
    else:
        check_case(args.path, args.format)
