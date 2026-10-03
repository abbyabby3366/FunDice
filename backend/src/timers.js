/**
 * Every timer the server arms goes through here, so `clearAll()` can stop them on shutdown.
 * Timers are unref'd (they never keep the process alive) and a throwing callback is reported
 * instead of crashing the server.
 */
export function createTimers({ onError }) {
  const active = new Set();

  const guarded = (callback) => () => {
    try {
      callback();
    } catch (error) {
      onError(error);
    }
  };

  return {
    /** Runs `callback` once after `ms`. Returns a function that cancels it. */
    after(ms, callback) {
      const handle = setTimeout(() => {
        active.delete(handle);
        guarded(callback)();
      }, ms);
      handle.unref();
      active.add(handle);
      return () => {
        clearTimeout(handle);
        active.delete(handle);
      };
    },

    /** Runs `callback` every `ms`. Returns a function that cancels it. */
    every(ms, callback) {
      const handle = setInterval(guarded(callback), ms);
      handle.unref();
      active.add(handle);
      return () => {
        clearInterval(handle);
        active.delete(handle);
      };
    },

    clearAll() {
      for (const handle of active) clearTimeout(handle);
      active.clear();
    },
  };
}
