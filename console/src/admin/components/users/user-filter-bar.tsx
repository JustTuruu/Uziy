import { Search, X } from "lucide-react";
import {
  Button,
  Input,
  SegmentedControl,
  Select,
  type SelectOption,
} from "@uziy/ui";
import {
  hasActiveFilters,
  NO_USER_FILTERS,
  type UserFilters,
  type VerificationFilter,
} from "@admin/lib/user-filters";

const VERIFICATION_OPTIONS = [
  { value: "ALL", label: "Бүгд" },
  { value: "VERIFIED", label: "Баталгаажсан" },
  { value: "UNVERIFIED", label: "Баталгаажаагүй" },
] as const satisfies readonly { value: VerificationFilter; label: string }[];

/** Above this many company options the menu gets its own type-ahead box. */
const COMPANY_SEARCH_MIN_OPTIONS = 6;

/**
 * The users page's filter row: phone text search, place and company pickers
 * from ready lists, the verification split and 'Цэвэрлэх'. Controlled — the
 * page owns [filters] and does the filtering (`filterUsers`).
 */
export function UserFilterBar({
  filters,
  onChange,
  cities,
  companies,
}: {
  filters: UserFilters;
  onChange: (filters: UserFilters) => void;
  cities: readonly SelectOption[];
  companies: readonly SelectOption[];
}) {
  const set = (patch: Partial<UserFilters>) => onChange({ ...filters, ...patch });

  return (
    <div className="mb-4 flex flex-wrap items-center gap-3">
      <div className="relative min-w-56 flex-1">
        <Search
          size={14}
          aria-hidden
          className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
        />
        <Input
          type="search"
          inputMode="tel"
          aria-label="Утасны дугаар"
          className="pl-9"
          placeholder="Утасны дугаараар хайх..."
          value={filters.phone}
          onChange={(e) => set({ phone: e.target.value })}
        />
      </div>
      <Select
        aria-label="Аймаг, хот"
        options={cities}
        value={filters.city}
        onValueChange={(city) => set({ city })}
      />
      <Select
        aria-label="Компани"
        options={companies}
        value={filters.companyId}
        onValueChange={(companyId) => set({ companyId })}
        searchable={companies.length > COMPANY_SEARCH_MIN_OPTIONS}
        searchPlaceholder="Компанийн нэрээр хайх..."
      />
      <SegmentedControl
        label="Статусын шүүлт"
        value={filters.verification}
        onChange={(verification) => set({ verification })}
        options={VERIFICATION_OPTIONS}
      />
      <Button
        variant="ghost"
        size="sm"
        leftIcon={<X size={12} aria-hidden />}
        disabled={!hasActiveFilters(filters)}
        onClick={() => onChange(NO_USER_FILTERS)}
      >
        Цэвэрлэх
      </Button>
    </div>
  );
}
