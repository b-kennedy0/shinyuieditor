import type { NodePath, PathElement } from "./NodePath";

export function makeChildPath(
  path: NodePath,
  childIndex: PathElement
): NodePath {
  return [...path, childIndex];
}

export function pathToString(path: NodePath): string {
  return path.join("-");
}
