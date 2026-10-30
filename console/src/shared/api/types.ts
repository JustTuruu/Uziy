import type { Schema } from "@uziy/api-types";

// The API's shapes, generated from the backend (docs/api/openapi.json → @uziy/api-types). Never retype a DTO by
// hand: a renamed or dropped field must fail `tsc` here, not show up as an empty cell.

export type Me = Schema<"Me">;
export type AuthResponse = Schema<"AuthResponse">;
export type Role = Me["role"];
export type Gender = NonNullable<Me["gender"]>;
