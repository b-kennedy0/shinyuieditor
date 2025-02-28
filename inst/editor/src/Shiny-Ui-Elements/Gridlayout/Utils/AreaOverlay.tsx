import React from "react";

import { FaGripLines, FaGripLinesVertical } from "react-icons/fa";

import type { ResizeDirection } from "../../../ui-node-definitions/gridlayout/gridTemplates/availableMoves";
import { availableMoves } from "../../../ui-node-definitions/gridlayout/gridTemplates/availableMoves";
import type { TemplatedGridProps } from "../../../ui-node-definitions/gridlayout/gridTemplates/TemplatedGridProps";
import type {
  ItemLocation,
  GridItemExtent,
} from "../../../ui-node-definitions/gridlayout/gridTemplates/types";
import { mergeClasses } from "../../../utils/mergeClasses";

import classes from "./AreaOverlay.module.css";
import { useResizeOnDrag } from "./useResizeOnDrag";

export function AreaOverlay({
  area,
  gridLocation,
  areas: layoutAreas,
  onNewPos,
}: {
  area: string;
  gridLocation?: ItemLocation;
  areas: TemplatedGridProps["areas"];
  onNewPos: (pos: GridItemExtent) => void;
}) {
  if (typeof gridLocation === "undefined")
    throw new Error(`Item in ${area} is not in the location map`);

  const overlayRef = React.useRef<HTMLDivElement>(null);

  const startDrag = useResizeOnDrag({
    overlayRef,
    gridLocation,
    layoutAreas,
    onDragEnd: onNewPos,
  });

  const movementOptions = React.useMemo(
    () => availableMoves({ gridLocation, layoutAreas }),
    [gridLocation, layoutAreas]
  );

  const movementHandles = React.useMemo(() => {
    let movementArrows: JSX.Element[] = [];

    for (let resizeDir of movementOptions) {
      movementArrows.push(
        <div
          key={resizeDir}
          className={mergeClasses(classes.dragger, resizeDir)}
          title={`resize ${area} ${resizeDir}`}
          onMouseDown={(e) => {
            stopEventPropigation(e);
            startDrag(resizeDir);
          }}
        >
          {resizeDirToArrow[resizeDir]}
        </div>
      );
    }
    return movementArrows;
  }, [area, movementOptions, startDrag]);

  React.useEffect(() => {
    overlayRef.current?.style.setProperty("--grid-area", area);
  }, [area]);

  return (
    <div
      ref={overlayRef}
      // We need to capture the click event here to prevent the drag from being
      // intepreted as a click on the parent element.
      onClick={stopEventPropigation}
      className={classes.marker + " grid-area-overlay"}
    >
      {movementHandles}
    </div>
  );
}

function stopEventPropigation(e: React.MouseEvent<HTMLElement>) {
  // These prevent this mousedown from triggering things like drag on the parent
  e.preventDefault();
  e.stopPropagation();
}

const resizeDirToArrow: Record<ResizeDirection, JSX.Element> = {
  up: <FaGripLines />,
  down: <FaGripLines />,
  left: <FaGripLinesVertical />,
  right: <FaGripLinesVertical />,
};
