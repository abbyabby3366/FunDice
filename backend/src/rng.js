import { randomInt } from 'node:crypto';

/**
 * The random source every rule uses, so tests can inject a deterministic one.
 * `int(n)` is uniform in [0, n); `float()` is uniform in [0, 1).
 */
export const cryptoRng = {
  int: (n) => randomInt(n),
  float: () => randomInt(2 ** 47) / 2 ** 47,
};
