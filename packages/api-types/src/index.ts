import type { components } from "./schema";

/**
 * The API's JSON shapes by their backend record name, e.g. `Schema<"CampaignDto">`. A field the server can leave
 * out is optional; everything else is required (see the backend's RequiredResponseFields).
 */
export type Schemas = components["schemas"];
export type Schema<Name extends keyof Schemas> = Schemas[Name];

export type { components, paths } from "./schema";
