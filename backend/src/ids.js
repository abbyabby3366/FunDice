import { randomUUID } from 'node:crypto';

/** Prefixed UUIDv4 identifiers: `usr_…`, `inv_…`, `gam_…`. */
export const newId = (prefix) => `${prefix}_${randomUUID()}`;

export const USER_ID = /^usr_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
