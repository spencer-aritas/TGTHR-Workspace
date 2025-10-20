/*
 * Centralized async helpers.
 * This file isolates permitted async operations (setTimeout/requestAnimationFrame)
 * so that consuming components can use microtask/delayed scheduling without
 * triggering the lint rule directly.
 */
/* eslint-disable @lwc/lwc/no-async-operation */
export function nextTick() {
  return Promise.resolve();
}

export function nextFrame() {
  return new Promise((resolve) => {
    requestAnimationFrame(resolve);
  });
}

export function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
