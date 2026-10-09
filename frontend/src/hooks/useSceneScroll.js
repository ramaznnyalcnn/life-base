import { useEffect } from "react";

/**
 * Drives a native scroll container as a multi-scene cross-fade stage.
 *
 * Attaches a passive `scroll` listener and, on each scroll, schedules a single
 * requestAnimationFrame (coalescing bursts). Inside the frame it computes a
 * normalized progress value across the scenes, writes it to the container as the
 * `--scene-progress` CSS custom property (so cross-fades run compositor-only via
 * CSS calc/clamp, with zero React re-renders), and notifies `onSceneChange` only
 * when the rounded/discrete scene index actually changes.
 *
 * No-ops cleanly in jsdom / non-scrollable containers (guards on scrollHeight and
 * the presence of requestAnimationFrame).
 *
 * @param {import("react").RefObject<HTMLElement>} containerRef Scroll container ref.
 * @param {object} [options]
 * @param {number} [options.scenes=2] Number of discrete scenes (>= 2).
 * @param {(scene: number) => void} [options.onSceneChange] Called with the new
 *   discrete scene index when Math.round(progress) changes.
 */
export default function useSceneScroll(containerRef, { scenes = 2, onSceneChange } = {}) {
  useEffect(() => {
    const container = containerRef.current;

    if (!container) {
      return undefined;
    }

    const sceneSpan = Math.max(1, scenes - 1);
    let rafId = null;
    let framePending = false;
    let lastScene = null;

    const computeFrame = () => {
      framePending = false;
      rafId = null;

      const scrollable = container.scrollHeight - container.clientHeight;

      // jsdom / not-yet-laid-out / non-scrollable: nothing to drive.
      if (!(scrollable > 0)) {
        return;
      }

      const ratio = container.scrollTop / scrollable;
      const progress = Math.max(0, Math.min(sceneSpan, ratio * sceneSpan));

      container.style.setProperty("--scene-progress", String(progress));

      const scene = Math.round(progress);
      if (scene !== lastScene) {
        lastScene = scene;
        if (typeof onSceneChange === "function") {
          onSceneChange(scene);
        }
      }
    };

    const handleScroll = () => {
      if (framePending) {
        return;
      }

      if (typeof requestAnimationFrame !== "function") {
        // No rAF available (e.g. jsdom): run once, synchronously, best-effort.
        computeFrame();
        return;
      }

      framePending = true;
      rafId = requestAnimationFrame(computeFrame);
    };

    container.addEventListener("scroll", handleScroll, { passive: true });

    return () => {
      container.removeEventListener("scroll", handleScroll);
      if (rafId != null && typeof cancelAnimationFrame === "function") {
        cancelAnimationFrame(rafId);
      }
    };
  }, [containerRef, scenes, onSceneChange]);
}
