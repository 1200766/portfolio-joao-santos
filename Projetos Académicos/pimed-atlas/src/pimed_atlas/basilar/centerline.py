"""Connected-component and centreline operations for a 3-D vessel mask.

All array coordinates and spacings use ``(z, y, x)`` order. Distances and
directions are evaluated in physical millimetres, with zero origin and an
identity direction matrix. A caller that uses another image direction must
transform its data and seeds before calling this module.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from heapq import heappop, heappush
from itertools import product

import numpy as np
from scipy import ndimage


@dataclass(frozen=True)
class SkeletonGraph:
    """A 26-neighbour graph whose edge weights are physical distances."""

    nodes_zyx: np.ndarray
    adjacency: tuple[tuple[tuple[int, float], ...], ...]
    spacing_zyx: tuple[float, float, float]


@dataclass(frozen=True)
class CenterlinePath:
    """An ordered geodesic path through a skeleton graph."""

    node_indices: tuple[int, ...]
    points_zyx: np.ndarray
    points_mm_zyx: np.ndarray
    length_mm: float
    automatic_endpoints: bool


def _validate_volume(volume: np.ndarray, name: str) -> np.ndarray:
    array = np.asarray(volume)
    if array.ndim != 3:
        raise ValueError(f"{name} must be a three-dimensional array")
    return array


def _validate_spacing(spacing_zyx: Sequence[float]) -> np.ndarray:
    spacing = np.asarray(spacing_zyx, dtype=float)
    if spacing.shape != (3,):
        raise ValueError("spacing_zyx must contain exactly three values")
    if not np.all(np.isfinite(spacing)) or np.any(spacing <= 0):
        raise ValueError("spacing_zyx values must be finite and positive")
    return spacing


def _integer_seed(
    seed_zyx: Sequence[int], shape: tuple[int, ...]
) -> tuple[int, int, int]:
    seed = np.asarray(seed_zyx, dtype=float)
    if seed.shape != (3,) or not np.all(np.isfinite(seed)):
        raise ValueError("seed_zyx must contain three finite coordinates")
    rounded = np.rint(seed)
    if not np.allclose(seed, rounded):
        raise ValueError("a component-selection seed must use integer indices")
    index = tuple(int(value) for value in rounded)
    if any(value < 0 or value >= shape[axis] for axis, value in enumerate(index)):
        raise ValueError("seed_zyx lies outside the volume")
    return index


def select_component_26(
    mask: np.ndarray,
    seed_zyx: Sequence[int] | None = None,
) -> np.ndarray:
    """Return one 26-connected foreground component from ``mask``.

    With a seed, the component containing that exact foreground voxel is
    selected. Without a seed, the largest component is selected; equal-size
    ties are resolved by the first component in array order.
    """

    foreground = _validate_volume(mask, "mask").astype(bool, copy=False)
    labels, component_count = ndimage.label(
        foreground,
        structure=np.ones((3, 3, 3), dtype=np.uint8),
    )
    if component_count == 0:
        raise ValueError("mask contains no foreground component")

    if seed_zyx is not None:
        seed = _integer_seed(seed_zyx, foreground.shape)
        selected_label = int(labels[seed])
        if selected_label == 0:
            raise ValueError("seed_zyx must lie on a foreground voxel")
    else:
        counts = np.bincount(labels.ravel())[1:]
        selected_label = int(np.argmax(counts)) + 1

    return labels == selected_label


def skeletonize_3d(mask: np.ndarray) -> np.ndarray:
    """Reduce a non-empty 3-D foreground mask to a one-voxel skeleton.

    ``skimage.morphology.skeletonize`` automatically uses Lee's method for a
    three-dimensional input. The result remains a Boolean NumPy array and no
    files or visual interfaces are involved.
    """

    foreground = _validate_volume(mask, "mask").astype(bool, copy=False)
    if not np.any(foreground):
        raise ValueError("mask contains no foreground voxels")

    try:
        from skimage.morphology import skeletonize
    except ImportError as error:  # pragma: no cover - depends on installation
        raise ImportError(
            "skeletonize_3d requires the declared scikit-image dependency"
        ) from error

    skeleton = np.asarray(skeletonize(foreground, method="lee"), dtype=bool)
    if not np.any(skeleton):
        raise RuntimeError("skeletonization returned an empty result")
    return skeleton


def build_skeleton_graph(
    skeleton: np.ndarray,
    spacing_zyx: Sequence[float],
) -> SkeletonGraph:
    """Build a weighted undirected graph from 26-neighbour skeleton voxels."""

    skeleton_array = _validate_volume(skeleton, "skeleton").astype(bool, copy=False)
    spacing = _validate_spacing(spacing_zyx)
    nodes = np.argwhere(skeleton_array)
    if len(nodes) == 0:
        raise ValueError("skeleton contains no foreground voxels")

    node_lookup = {tuple(point): index for index, point in enumerate(nodes)}
    neighbour_offsets = tuple(
        offset for offset in product((-1, 0, 1), repeat=3) if offset != (0, 0, 0)
    )
    adjacency_lists: list[list[tuple[int, float]]] = [[] for _ in nodes]

    for source, point in enumerate(nodes):
        point_tuple = tuple(int(value) for value in point)
        for offset in neighbour_offsets:
            neighbour = tuple(point_tuple[axis] + offset[axis] for axis in range(3))
            target = node_lookup.get(neighbour)
            if target is None or target <= source:
                continue
            weight = float(np.linalg.norm(np.asarray(offset, dtype=float) * spacing))
            adjacency_lists[source].append((target, weight))
            adjacency_lists[target].append((source, weight))

    adjacency = tuple(
        tuple(sorted(neighbours, key=lambda item: item[0]))
        for neighbours in adjacency_lists
    )
    return SkeletonGraph(
        nodes_zyx=nodes.astype(np.int64, copy=False),
        adjacency=adjacency,
        spacing_zyx=tuple(float(value) for value in spacing),
    )


def _connected_components(graph: SkeletonGraph) -> list[tuple[int, ...]]:
    unseen = set(range(len(graph.nodes_zyx)))
    components: list[tuple[int, ...]] = []
    while unseen:
        first = min(unseen)
        stack = [first]
        unseen.remove(first)
        component: list[int] = []
        while stack:
            node = stack.pop()
            component.append(node)
            for neighbour, _ in graph.adjacency[node]:
                if neighbour in unseen:
                    unseen.remove(neighbour)
                    stack.append(neighbour)
        components.append(tuple(sorted(component)))
    return components


def _nearest_node(
    graph: SkeletonGraph,
    seed_zyx: Sequence[float],
) -> int:
    seed = np.asarray(seed_zyx, dtype=float)
    if seed.shape != (3,) or not np.all(np.isfinite(seed)):
        raise ValueError("each centreline seed must contain three finite coordinates")
    spacing = np.asarray(graph.spacing_zyx)
    distances_squared = np.sum(
        ((graph.nodes_zyx.astype(float) - seed) * spacing) ** 2,
        axis=1,
    )
    return int(np.argmin(distances_squared))


def _dijkstra(
    graph: SkeletonGraph,
    start: int,
    allowed: set[int] | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    distances = np.full(len(graph.nodes_zyx), np.inf, dtype=float)
    previous = np.full(len(graph.nodes_zyx), -1, dtype=np.int64)
    distances[start] = 0.0
    queue: list[tuple[float, int]] = [(0.0, start)]

    while queue:
        distance, source = heappop(queue)
        if distance > distances[source]:
            continue
        for target, weight in graph.adjacency[source]:
            if allowed is not None and target not in allowed:
                continue
            candidate = distance + weight
            if candidate < distances[target]:
                distances[target] = candidate
                previous[target] = source
                heappush(queue, (candidate, target))
    return distances, previous


def _farthest_node(distances: np.ndarray, candidates: Sequence[int]) -> int:
    reachable = [node for node in candidates if np.isfinite(distances[node])]
    if not reachable:
        raise ValueError("no reachable node exists in the selected skeleton component")
    return max(reachable, key=lambda node: (float(distances[node]), -node))


def _automatic_endpoints(graph: SkeletonGraph) -> tuple[int, int]:
    components = _connected_components(graph)
    component = max(components, key=lambda item: (len(item), -item[0]))
    if len(component) == 1:
        return component[0], component[0]

    allowed = set(component)
    edge_count = sum(
        1
        for source in component
        for target, _ in graph.adjacency[source]
        if target in allowed and target > source
    )
    if edge_count != len(component) - 1:
        raise ValueError(
            "automatic endpoint selection only supports an acyclic skeleton; "
            "provide explicit start and end seeds"
        )
    first = component[0]
    first_distances, _ = _dijkstra(graph, first, allowed)
    start = _farthest_node(first_distances, component)
    start_distances, _ = _dijkstra(graph, start, allowed)
    end = _farthest_node(start_distances, component)
    return start, end


def geodesic_centerline(
    graph: SkeletonGraph,
    start_seed_zyx: Sequence[float] | None = None,
    end_seed_zyx: Sequence[float] | None = None,
) -> CenterlinePath:
    """Order skeleton nodes along a shortest physical path.

    Supplying two seeds selects the nearest skeleton node to each seed and
    computes the geodesic between them. Supplying neither enables a deterministic
    automatic mode intended for simple synthetic skeletons: a two-sweep graph
    diameter is extracted from the largest connected skeleton component. The
    automatic mode rejects cycles because its endpoint choice would otherwise
    be ambiguous.
    """

    if not isinstance(graph, SkeletonGraph):
        raise TypeError("graph must be a SkeletonGraph")
    if (start_seed_zyx is None) != (end_seed_zyx is None):
        raise ValueError("provide both centreline seeds or neither")

    automatic = start_seed_zyx is None
    if automatic:
        start, end = _automatic_endpoints(graph)
    else:
        start = _nearest_node(graph, start_seed_zyx)
        end = _nearest_node(graph, end_seed_zyx)

    distances, previous = _dijkstra(graph, start)
    if not np.isfinite(distances[end]):
        raise ValueError(
            "the selected centreline seeds belong to disconnected skeletons"
        )

    reversed_path = [end]
    while reversed_path[-1] != start:
        predecessor = int(previous[reversed_path[-1]])
        if predecessor < 0:
            raise RuntimeError("could not reconstruct the geodesic path")
        reversed_path.append(predecessor)
    node_indices = tuple(reversed(reversed_path))
    points_zyx = graph.nodes_zyx[np.asarray(node_indices, dtype=int)].copy()
    spacing = np.asarray(graph.spacing_zyx)

    return CenterlinePath(
        node_indices=node_indices,
        points_zyx=points_zyx,
        points_mm_zyx=points_zyx.astype(float) * spacing,
        length_mm=float(distances[end]),
        automatic_endpoints=automatic,
    )


def estimate_tangents(
    points_zyx: np.ndarray,
    spacing_zyx: Sequence[float],
    window: int = 2,
) -> np.ndarray:
    """Estimate consistently oriented unit tangents in physical ``zyx`` axes."""

    points = np.asarray(points_zyx, dtype=float)
    spacing = _validate_spacing(spacing_zyx)
    if points.ndim != 2 or points.shape[1] != 3:
        raise ValueError("points_zyx must have shape (n, 3)")
    if len(points) < 2:
        raise ValueError("at least two ordered centreline points are required")
    if not isinstance(window, int) or isinstance(window, bool) or window < 1:
        raise ValueError("window must be a positive integer")

    physical_points = points * spacing
    tangents = np.empty_like(physical_points)
    for index in range(len(physical_points)):
        lower = max(0, index - window)
        upper = min(len(physical_points) - 1, index + window)
        difference = physical_points[upper] - physical_points[lower]
        norm = float(np.linalg.norm(difference))
        if norm == 0:
            for radius in range(1, len(physical_points)):
                lower = max(0, index - radius)
                upper = min(len(physical_points) - 1, index + radius)
                difference = physical_points[upper] - physical_points[lower]
                norm = float(np.linalg.norm(difference))
                if norm > 0:
                    break
        if norm == 0:
            raise ValueError("centreline points do not define a local direction")
        tangents[index] = difference / norm

    for index in range(1, len(tangents)):
        if float(np.dot(tangents[index - 1], tangents[index])) < 0:
            tangents[index] *= -1
    return tangents
